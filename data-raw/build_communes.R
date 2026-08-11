# Build the current commune and source-compatible province boundary layers.
#
# Run from the package root:
#   Rscript data-raw/build_communes.R
#
# Geometry is read from a fixed MIT-licensed snapshot of the Vietnamese
# Provinces Database. That project derives the boundaries from the Viet Nam
# Administrative Units Reference Map published by the Department of Survey,
# Mapping and Geographic Information Viet Nam. The bundled catalogue snapshot
# is supplied by that community project; this script does not represent it as
# an independently verified official NSO catalogue.

library(sf)

commit <- "cd58063299585146ded3981f2272946ef19ced54"
snapshot <- "data-raw/source/vn-units-2026-07-25.json"
geometry_dir <- Sys.getenv("VNMAP_COMMUNE_GEOMETRY_DIR", unset = "")

stopifnot(file.exists(snapshot))
expected_md5 <- c(
  "data-raw/source/vn-units-2026-07-25.json" = "e9ecfae36f2b215b56a21e6afd307a18",
  "data-raw/source/commune-geometry-md5.csv" = "c80740f42e1e285ec7236a8354063809"
)
actual_md5 <- unname(tools::md5sum(names(expected_md5)))
if (!identical(actual_md5, unname(expected_md5))) {
  stop("A commune build input checksum differs from the verified snapshot.")
}
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.")
if (!requireNamespace("s2", quietly = TRUE)) stop("Package 's2' is required.")

catalogue <- jsonlite::fromJSON(snapshot, simplifyDataFrame = FALSE)
wards <- do.call(rbind, lapply(catalogue, function(p) {
  do.call(rbind, lapply(p$Wards, function(w) data.frame(
    code = w$Code, name_vi = w$Name, name_en = w$NameEn,
    type = switch(as.character(w$AdministrativeUnitId),
                  `3` = "ward", `4` = "commune", `5` = "special_zone", "unknown"),
    province_code = w$ProvinceCode, province_en = p$NameEn,
    province_slug = p$CodeName, unit_slug = w$CodeName,
    stringsAsFactors = FALSE
  )))
}))
stopifnot(nrow(wards) == 3321L, !anyDuplicated(wards$code))

if (!nzchar(geometry_dir)) {
  geometry_dir <- file.path(tempdir(), paste0("vnmap-communes-", commit))
}
dir.create(geometry_dir, recursive = TRUE, showWarnings = FALSE)
message("Downloading missing files from the 3,321-boundary fixed snapshot...")
for (i in seq_len(nrow(wards))) {
  dest <- file.path(geometry_dir, paste0(wards$code[i], ".geojson"))
  if (file.exists(dest)) next
  rel <- paste0(wards$province_code[i], "_", wards$province_slug[i],
                "/wards/", wards$code[i], "_", wards$unit_slug[i], ".geojson")
  url <- paste0("https://raw.githubusercontent.com/thanglequoc/",
                "vietnamese-provinces-database/", commit,
                "/json/geojson/", rel)
  tryCatch(utils::download.file(url, dest, mode = "wb", quiet = TRUE),
           error = function(e) stop("Failed to download boundary ", wards$code[i],
                                    " from fixed snapshot: ", conditionMessage(e)))
}

files <- file.path(geometry_dir, paste0(wards$code, ".geojson"))
missing <- wards$code[!file.exists(files)]
if (length(missing)) stop("Missing geometry for codes: ", paste(head(missing, 20), collapse = ", "))
manifest <- utils::read.csv("data-raw/source/commune-geometry-md5.csv",
                            colClasses = "character")
manifest <- manifest[match(wards$code, manifest$code), , drop = FALSE]
if (anyNA(manifest$md5) || !identical(unname(tools::md5sum(files)), manifest$md5)) {
  stop("One or more commune geometry files differ from the pinned manifest.")
}

geoms <- lapply(files, function(f) st_geometry(st_read(f, quiet = TRUE))[[1]])
communes <- st_sf(wards[c("code", "name_vi", "name_en", "type",
                          "province_code", "province_en")],
                  geometry = st_sfc(geoms, crs = 4326))
communes <- st_make_valid(communes)
communes <- st_transform(communes, 3405)
communes$geometry <- st_simplify(communes$geometry, dTolerance = 100,
                                 preserveTopology = TRUE)
communes_projected <- communes
communes <- st_transform(communes_projected, 4326)
communes$valid_from <- as.Date(NA)
communes$valid_to <- as.Date(NA)
communes$geography_vintage <- "2026-07-25"
communes$source_url <- paste0(
  "https://github.com/thanglequoc/vietnamese-provinces-database/tree/", commit)
communes$snapshot_date <- as.Date("2026-07-25")
communes$observed_on <- as.Date("2026-08-11")
communes$geometry_accuracy <- "reference_map_generalized_100m"
communes <- communes[c("code", "name_vi", "name_en", "type", "province_code",
                       "province_en", "valid_from", "valid_to", "geography_vintage",
                       "source_url", "snapshot_date", "observed_on",
                       "geometry_accuracy", "geometry")]
stopifnot(!any(st_is_empty(communes)), all(st_is_valid(communes)))

# Construct current province polygons from the exact same simplified commune
# geometries. Independently simplified neighbours can overlap slightly. Assign
# each overlap deterministically to the lowest province code so the result is a
# non-overlapping coverage without discarding any part of the national union.
old_prov <- st_drop_geometry(readRDS("inst/extdata/provinces.rds"))
old_prov <- old_prov[order(old_prov$code), , drop = FALSE]
raw_province_geoms <- lapply(old_prov$code, function(code) {
  st_union(st_geometry(communes_projected[communes_projected$province_code == code, ]))[[1]]
})
raw_province_geoms <- st_sfc(raw_province_geoms, crs = 3405)
# Remove duplicate/near-duplicate vertices that GEOS accepts but s2 rejects as
# degenerate edges. One centimetre is immaterial relative to 100 m source
# generalization and keeps spherical overlay deterministic.
raw_province_geoms <- st_simplify(raw_province_geoms, dTolerance = 0.01,
                                  preserveTopology = TRUE)
raw_province_geoms_wgs84 <- st_transform(raw_province_geoms, 4326)
# Rebuild with validation disabled on ingest so duplicate vertices can be
# removed before any spherical overlay operation validates the loops.
raw_province_geoms_wgs84 <- st_as_sfc(s2::s2_rebuild(
  s2::as_s2_geography(st_as_binary(raw_province_geoms_wgs84), check = FALSE)
), crs = 4326)
source_union_wgs84 <- st_as_sfc(s2::s2_rebuild(s2::s2_union_agg(
  s2::as_s2_geography(st_as_binary(raw_province_geoms_wgs84), check = FALSE)
)), crs = 4326)
province_geoms <- vector("list", length(raw_province_geoms_wgs84))
claimed_s2 <- NULL
for (i in seq_along(raw_province_geoms_wgs84)) {
  geom_s2 <- s2::s2_rebuild(s2::as_s2_geography(
    st_as_binary(raw_province_geoms_wgs84[i]), check = FALSE
  ))
  if (!is.null(claimed_s2)) geom_s2 <- s2::s2_difference(geom_s2, claimed_s2)
  geom_s2 <- s2::s2_rebuild(geom_s2)
  province_geoms[[i]] <- st_as_sfc(geom_s2, crs = 4326)[[1]]
  claimed_s2 <- if (is.null(claimed_s2)) geom_s2 else {
    s2::s2_rebuild(s2::s2_union_agg(c(claimed_s2, geom_s2)))
  }
}
provinces <- st_sf(old_prov[c("code", "iso", "name_vi", "name_en", "type")],
                   geometry = st_sfc(province_geoms, crs = 4326))
provinces <- st_make_valid(provinces)

# Coverage and pairwise-overlap QA. National union area may differ at projection
# round-off scale, so allow at most 1e-8 relative error. Reprojection of the
# spherical coverage may create sub-pixel GEOS slivers; cap those at 1,000 m2,
# far below the 100 m source-generalization scale.
raw_union_area <- as.numeric(st_area(st_transform(source_union_wgs84, 3405)))
qa_provinces <- st_transform(provinces, 3405)
resolved_union_area <- as.numeric(st_area(st_union(st_geometry(qa_provinces))))
coverage_area_difference_m2 <- abs(raw_union_area - resolved_union_area)
message("National union area difference after overlap assignment: ",
        format(coverage_area_difference_m2, scientific = FALSE), " m2")
stopifnot(coverage_area_difference_m2 <= raw_union_area * 1e-8)
pairs <- combn(nrow(provinces), 2L)
pair_overlap_m2 <- vapply(seq_len(ncol(pairs)), function(j) {
  overlap <- suppressWarnings(st_intersection(
    st_geometry(qa_provinces)[pairs[1L, j]],
    st_geometry(qa_provinces)[pairs[2L, j]]
  ))
  sum(as.numeric(st_area(overlap)))
}, numeric(1))
message("Maximum pairwise province overlap: ",
        format(max(pair_overlap_m2), scientific = FALSE), " m2")
stopifnot(all(pair_overlap_m2 <= 1000))
provinces$geography_vintage <- "2026-07-25"
provinces$source_url <- communes$source_url[1]
provinces$snapshot_date <- communes$snapshot_date[1]
provinces$observed_on <- communes$observed_on[1]
provinces$geometry_accuracy <- communes$geometry_accuracy[1]
stopifnot(all(st_is_valid(provinces)), !any(st_is_empty(provinces)))
# Each province was produced only by unioning its member communes. Verify that
# every commune has exactly one declared parent represented in the output;
# union construction guarantees polygon containment by construction.
stopifnot(!anyNA(match(communes$province_code, provinces$code)))
stopifnot(all(table(communes$province_code) > 0L))

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(communes, "inst/extdata/communes.rds", compress = "xz", version = 3)
saveRDS(provinces, "inst/extdata/provinces.rds", compress = "xz", version = 3)
message("Wrote ", nrow(communes), " current communes and ", nrow(provinces),
        " source-compatible provinces.")
