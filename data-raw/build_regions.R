# Build the socio-economic region lookup table.
#
# Run `Rscript data-raw/build_regions.R` from the package root. This script
# uses only base R, so it does not require 'sf'.
#
# The six regions follow the socio-economic regions published by the General
# Statistics Office of Viet Nam. Assignments for the historical 63-unit
# geography are taken directly from `data-raw/regions_63.csv`. Assignments for
# the current 34-unit geography are derived: each 2025 unit is placed in the
# region that holds the largest share of its 2024 population among the former
# units it absorbed. This rule is documented and fully reproducible.

regions_63 <- read.csv("data-raw/regions_63.csv", colClasses = "character",
                       check.names = FALSE, encoding = "UTF-8")
regions_63 <- regions_63[order(as.integer(regions_63$code)), ]
stopifnot(nrow(regions_63) == 63L, !anyNA(regions_63$region_code))

current <- read.csv("data-raw/provinces_34.csv", colClasses = "character",
                    check.names = FALSE, encoding = "UTF-8")

# 2024 population is used to break up cross-region mergers deterministically.
env <- new.env()
load("data/province_stats_2024_63.rda", envir = env)
pop63 <- env$province_stats_2024_63[c("code", "population")]

region_of <- function(code) regions_63$region_code[match(code, regions_63$code)]
labels <- regions_63[!duplicated(regions_63$region_code),
                     c("region_code", "region_vi", "region_en")]

current_rows <- lapply(seq_len(nrow(current)), function(i) {
  members <- strsplit(current$members[i], "+", fixed = TRUE)[[1]]
  pops <- pop63$population[match(members, pop63$code)]
  by_region <- tapply(pops, region_of(members), sum)
  dominant <- names(by_region)[which.max(by_region)]
  data.frame(code = current$code[i], region_code = dominant,
             stringsAsFactors = FALSE)
})
provinces <- do.call(rbind, current_rows)
provinces <- merge(provinces, labels, by = "region_code", sort = FALSE)
provinces <- provinces[order(as.integer(provinces$code)),
                       c("code", "region_code", "region_vi", "region_en")]
stopifnot(nrow(provinces) == 34L, !anyNA(provinces$region_code))

regions <- list(
  provinces = provinces,
  provinces_63 = regions_63[c("code", "region_code", "region_vi", "region_en")]
)
rownames(regions$provinces) <- NULL
rownames(regions$provinces_63) <- NULL

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(regions, "inst/extdata/regions.rds")
message("Wrote inst/extdata/regions.rds")
