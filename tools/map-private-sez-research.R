# Local research-only derived outputs; never write GESIS data into inst/ or output/.
library(sf)
library(ggplot2)
library(stringi)
root <- "tmp/industrial-research"
p <- st_read(file.path(root, "sez-research-sites.geojson"), quiet = TRUE)
stopifnot(nrow(p) == 611L, !anyDuplicated(p$sez_id), all(st_is_valid(p)))
provinces <- st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
hits <- st_intersects(p, provinces)
p$province_code <- vapply(hits, function(h) if (length(h) == 1L) provinces$code[h] else NA_character_, "")
key <- function(x) {
  x[is.na(x)] <- ""
  x <- tolower(stri_trans_general(x, "Latin-ASCII"))
  x <- sub("/.*$", "", x)
  x <- trimws(gsub(" +", " ", gsub("[^a-z0-9]+", " ", x)))
  x <- sub("^(industrial zone|industrial park|khu cong nghiep|khu cn|kcn|khu che xuat|kcx|cum cong nghiep|ccn) +", "", x)
  x <- sub(" +(industrial park|industrial zone)$", "", x)
  for (i in seq_along(c("i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x")))
    x <- gsub(paste0("\\b", c("i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x")[i], "\\b"), as.character(i), x)
  x
}
p$key <- key(p[["SEZ.name"]])
sources <- read.csv("data-raw/industrial-park-sources.csv", colClasses = "character", na.strings = "")
sources$research_sez_id <- NA_character_
sources$research_match_method <- NA_character_
for (i in seq_len(nrow(sources))) {
  h <- which(p$key == key(sources$name_vi[i]) & nzchar(p$key) &
    !is.na(p$province_code) & !is.na(sources$province_code[i]) & p$province_code == sources$province_code[i] &
    p[["Type.of.Zone"]] == "Industrial Zone" &
    sources$category[i] %in% c("industrial_park", "export_processing_zone"))
  if (length(h) == 1L) {
    sources$research_sez_id[i] <- p$sez_id[h]
    sources$research_match_method[i] <- "exact_name_and_province_research_source_not_legal_verification"
  }
}
xy <- st_coordinates(p)
i <- match(sources$research_sez_id, p$sez_id)
sources$research_longitude <- xy[i, 1]
sources$research_latitude <- xy[i, 2]
sources$research_source_url <- ifelse(is.na(i), NA_character_, "https://doi.org/10.7802/2762")
sources$has_any_location <- !is.na(sources$map_id) | !is.na(sources$research_sez_id)
write.csv(sources, file.path(root, "source-reconciliation.csv"), row.names = FALSE, na = "")
write.csv(sources[!sources$has_any_location, ], file.path(root, "unresolved-source-records.csv"), row.names = FALSE, na = "")
st_write(p, file.path(root, "sez-research-sites-with-province.geojson"), delete_dsn = TRUE, quiet = TRUE)
coverage <- do.call(rbind, lapply(unique(sources$source), function(s) {
  x <- sources[sources$source == s, ]
  data.frame(source = s, source_rows = nrow(x), public_linked = sum(!is.na(x$map_id)),
    research_linked = sum(!is.na(x$research_sez_id)), any_location = sum(x$has_any_location),
    unresolved = sum(!x$has_any_location))
}))
write.csv(coverage, file.path(root, "coverage.csv"), row.names = FALSE)
p$zone_type <- p[["Type.of.Zone"]]
p$zone_type[is.na(p$zone_type)] <- "Missing in source"
g <- ggplot() + geom_sf(data = provinces, fill = "#f0f1ed", color = "#c4c9c3", linewidth = .15) +
  geom_sf(data = p, aes(color = zone_type), size = 1.2, alpha = .75) +
  scale_color_manual(values = c("Industrial Zone" = "#166b70", "Coastal Economic Zone" = "#c8772b",
    "Cross-border Economic Zone" = "#76528b", "Missing in source" = "#a83232"), name = NULL) +
  labs(title = "Vietnam SEZs: 611 source locations", subtitle = "Research dataset covering 1991–2022 | All metadata IDs linked to KML points",
    caption = "Tafese, Lay & Tran (2025), version 1.0.0. DOI: 10.7802/2762.\nLocal scientific research use only. Not a complete 2026 register or legal boundary map.") +
  theme_void() + theme(legend.position = "bottom", legend.text = element_text(size = 8),
    plot.title = element_text(size = 20, face = "bold"), plot.subtitle = element_text(size = 10),
    plot.caption = element_text(hjust = 0, size = 8), plot.margin = margin(20,20,20,20))
ggsave(file.path(root, "sez-research-map.png"), g, width = 10, height = 12, dpi = 180)
print(coverage)
