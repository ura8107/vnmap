# Build the historical commune-level (ADM3) layer.
#
# Run `Rscript data-raw/build_adm3.R` from the package root. Requires 'sf' and
# internet access. This produces `inst/extdata/communes_63.rds`, the optional
# layer returned by `vn_map("communes_63")`.
#
# IMPORTANT: The July 2025 reform (Decision 19/2025/QD-TTg) abolished the
# district tier and merged Viet Nam's communes, so the pre-reform commune
# geography no longer exists administratively. This layer is HISTORICAL,
# describing communes (xa / phuong / thi tran) as they existed before
# 1 July 2025, and is intended for statistical visualization of pre-reform
# commune data only.
#
# The layer holds many thousands of polygons. It is deliberately NOT bundled
# with the package (it would exceed the CRAN size limit) and is excluded from
# the build via .Rbuildignore. Draw it filtered to a province rather than
# nationwide. Commune names are not unique across Viet Nam, so joins should use
# the `province_code` column together with the name, not the name alone.
#
# Source: geoBoundaries Viet Nam ADM3, public domain. As with the other builds,
# the shapes are generalized and unsuitable for surveying or legal boundary
# determinations.

library(sf)

url <- "https://www.geoboundaries.org/api/current/gbOpen/VNM/ADM3/"

# The geoBoundaries API returns JSON with a `simplifiedGeometryGeoJSON` URL.
meta <- jsonlite::fromJSON(url)
geojson <- meta$simplifiedGeometryGeoJSON
raw <- st_read(geojson, quiet = TRUE)
raw <- st_make_valid(raw)

# geoBoundaries ADM3 carries the commune name in `shapeName` and a stable
# `shapeID`. Parent province is not stored, so it is assigned spatially below.
communes <- raw
communes$name_en <- communes$shapeName
communes$code <- communes$shapeID
communes$name_vi <- NA_character_
communes <- st_transform(communes[c("code", "name_vi", "name_en", "geometry")], 3405)
stopifnot(nrow(communes) > 0L, !any(st_is_empty(communes)))

# Assign each commune to a pre-July-2025 (63-unit) province by spatial
# containment of a representative interior point, falling back to the nearest
# province for points that fall outside the generalized provincial polygons.
prov <- st_transform(readRDS("inst/extdata/provinces_63.rds"), st_crs(communes))
reps <- suppressWarnings(st_point_on_surface(st_geometry(communes)))
within <- st_within(reps, prov)
idx <- vapply(within, function(i) if (length(i)) i[[1]] else NA_integer_, integer(1))
if (anyNA(idx)) idx[is.na(idx)] <- st_nearest_feature(reps[is.na(idx)], prov)
communes$province_code <- prov$code[idx]
communes$province_en <- prov$name_en[idx]
communes <- communes[c("code", "name_vi", "name_en",
                       "province_code", "province_en", "geometry")]

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(communes, "inst/extdata/communes_63.rds", compress = "xz")
message("Wrote inst/extdata/communes_63.rds with ", nrow(communes), " communes")
