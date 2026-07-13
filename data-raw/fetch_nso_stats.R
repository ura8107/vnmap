# Download and prepare 2024 provincial statistics from Viet Nam's NSO PX-Web.
# Run from the package root. Internet access is required.

library(rvest)
library(xml2)

population_url <- paste0(
  "https://pxweb.nso.gov.vn/pxweb/en/Population%20and%20Employment/",
  "Population%20and%20Employment/E02.01.px/",
  "?rxid=83acf925-cd77-4434-a114-126412d3fa2a"
)
grdp_url <- paste0(
  "https://pxweb.nso.gov.vn/pxweb/en/National%20Accounts%20and%20State%20budget/",
  "National%20Accounts%20and%20State%20budget/E03.12.px/",
  "?rxid=3f5a3111-7b07-4063-a668-6f7c9d9af909"
)

px_table <- function(url, selections) {
  session <- rvest::session(url)
  form <- rvest::html_form(session)[[1]]
  fields <- names(form$fields)
  selects <- fields[vapply(form$fields, function(x) identical(x$type, "select"), logical(1))]
  stopifnot(length(selects) == length(selections) + 1L)
  values <- c(selections, list("tableViewLayout1"))
  names(values) <- selects
  form <- do.call(rvest::html_form_set, c(list(form), values))
  submit <- fields[vapply(form$fields, function(x) {
    identical(x$type, "submit") && grepl("ButtonViewTable", x$name)
  }, logical(1))][1]
  response <- rvest::session_submit(session, form, submit = submit)$response
  rvest::html_table(xml2::read_html(response$content), fill = TRUE)[[1]]
}

# PX-Web option values include six regions (and, for population, the country).
population_options <- setdiff(as.character(0:69), c("0", "1", "13", "28", "43", "49", "56"))
grdp_options <- setdiff(as.character(0:68), c("0", "12", "27", "42", "48", "55"))

population_raw <- px_table(
  population_url,
  list(population_options, "13", c("0", "1", "2"))
)
grdp_raw <- px_table(grdp_url, list(grdp_options, "6"))

names(population_raw) <- c("source_name", "area_km2", "population_thousands", "density_source")
population_raw <- population_raw[-c(1, 2), ]
names(grdp_raw) <- c("source_name", "grdp_per_capita_million_vnd")
grdp_raw <- grdp_raw[-1, ]

number <- function(x) as.numeric(gsub(",", "", x, fixed = TRUE))
for (column in names(population_raw)[-1]) population_raw[[column]] <- number(population_raw[[column]])
grdp_raw$grdp_per_capita_million_vnd <- number(grdp_raw$grdp_per_capita_million_vnd)

key <- function(x) {
  x <- stringi::stri_trans_general(x, "Latin-ASCII")
  gsub("[^a-z0-9]", "", tolower(x))
}
old_meta <- read.csv("data-raw/provinces_63.csv", colClasses = "character", check.names = FALSE)
old_meta$join_key <- key(old_meta$name_en)
population_raw$join_key <- key(population_raw$source_name)
grdp_raw$join_key <- key(grdp_raw$source_name)

province_stats_2024_63 <- merge(
  old_meta[c("code", "iso", "name_vi", "name_en", "type", "join_key")],
  population_raw,
  by = "join_key",
  all.x = TRUE,
  sort = FALSE
)
province_stats_2024_63 <- merge(
  province_stats_2024_63,
  grdp_raw[c("join_key", "grdp_per_capita_million_vnd")],
  by = "join_key",
  all.x = TRUE,
  sort = FALSE
)
stopifnot(nrow(province_stats_2024_63) == 63L)
stopifnot(!anyNA(province_stats_2024_63[c("area_km2", "population_thousands", "grdp_per_capita_million_vnd")]))
province_stats_2024_63 <- province_stats_2024_63[order(as.integer(province_stats_2024_63$code)), ]
province_stats_2024_63$population <- round(province_stats_2024_63$population_thousands * 1000)
province_stats_2024_63$population_density <- province_stats_2024_63$population / province_stats_2024_63$area_km2
province_stats_2024_63$year <- 2024L
province_stats_2024_63$grdp_preliminary <- TRUE
province_stats_2024_63$source_name <- NULL
province_stats_2024_63$density_source <- NULL
province_stats_2024_63$join_key <- NULL
province_stats_2024_63 <- province_stats_2024_63[c(
  "code", "iso", "name_vi", "name_en", "type", "year", "area_km2",
  "population", "population_thousands", "population_density",
  "grdp_per_capita_million_vnd", "grdp_preliminary"
)]

current <- read.csv("data-raw/provinces_34.csv", colClasses = "character", check.names = FALSE)
province_stats_2024 <- do.call(rbind, lapply(seq_len(nrow(current)), function(i) {
  member_codes <- strsplit(current$members[i], "+", fixed = TRUE)[[1]]
  members <- province_stats_2024_63[province_stats_2024_63$code %in% member_codes, ]
  population <- sum(members$population)
  area <- sum(members$area_km2)
  data.frame(
    code = current$code[i], name_vi = current$name_vi[i], name_en = current$name_en[i],
    type = current$type[i], year = 2024L, area_km2 = area,
    population = population, population_thousands = population / 1000,
    population_density = population / area,
    grdp_per_capita_million_vnd = weighted.mean(
      members$grdp_per_capita_million_vnd, members$population
    ),
    grdp_preliminary = TRUE, member_codes = paste(member_codes, collapse = "+"),
    stringsAsFactors = FALSE
  )
}))
province_stats_2024 <- province_stats_2024[order(as.integer(province_stats_2024$code)), ]

dir.create("data", showWarnings = FALSE)
dir.create("data-raw/source", recursive = TRUE, showWarnings = FALSE)
write.csv(province_stats_2024_63, "data-raw/source/nso_province_stats_2024_63.csv", row.names = FALSE)
save(province_stats_2024_63, file = "data/province_stats_2024_63.rda", compress = "xz")
save(province_stats_2024, file = "data/province_stats_2024.rda", compress = "xz")
