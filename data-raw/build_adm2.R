# Build the historical district-level (ADM2) layer.
#
# Run `Rscript data-raw/build_adm2.R` from the package root. Requires 'sf' and
# internet access. This produces `inst/extdata/districts_63.rds`, the optional
# layer returned by `vn_map("districts_63")`.
#
# IMPORTANT: The July 2025 reform (Decision 19/2025/QD-TTg) abolished the
# district administrative tier entirely, moving Viet Nam to a two-level
# province -> commune structure. There is therefore no current ADM2 geography;
# this layer is HISTORICAL, describing districts as they existed before
# 1 July 2025, and is intended for statistical visualization of pre-reform
# district data only.
#
# Source: geoBoundaries Viet Nam ADM2, public domain. As with the ADM1 build,
# the shapes are generalized and unsuitable for surveying or legal boundary
# determinations.

library(sf)

url <- paste0(
  "https://www.geoboundaries.org/api/current/gbOpen/VNM/ADM2/"
)

# The geoBoundaries API returns JSON with a `simplifiedGeometryGeoJSON` URL.
meta <- jsonlite::fromJSON(url)
geojson <- meta$simplifiedGeometryGeoJSON
raw <- st_read(geojson, quiet = TRUE)
raw <- st_make_valid(raw)

ascii <- function(x) {
  x <- stringi::stri_trans_general(x, "Latin-ASCII")
  gsub("[^a-z0-9]", "", tolower(x))
}

# geoBoundaries ADM2 carries the district name in `shapeName` and a stable
# `shapeID`. We keep a normalized key for name-based joins and matching.
districts <- raw
districts$name_en <- districts$shapeName
districts$code <- districts$shapeID
districts$name_vi <- NA_character_
districts <- districts[c("code", "name_vi", "name_en", "geometry")]
districts <- st_transform(districts, 3405)
stopifnot(nrow(districts) > 0L, !any(st_is_empty(districts)))

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(districts, "inst/extdata/districts_63.rds", compress = "xz")
message("Wrote inst/extdata/districts_63.rds with ", nrow(districts), " districts")
