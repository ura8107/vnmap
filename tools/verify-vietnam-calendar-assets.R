args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[[1L]] else "app-assets/vietnam-calendar"

suppressPackageStartupMessages({
  library(sf)
  library(vnmap)
})

geojson <- st_read(file.path(output_dir, "vietnam-provinces-34.geojson"), quiet = TRUE)
stats <- read.csv(
  file.path(output_dir, "province-stats-2024.csv"),
  colClasses = c(code = "character"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
expected <- vn_map(crs = 4326)
data("province_stats_2024", package = "vnmap", envir = environment())
expected_stats <- province_stats_2024[
  order(as.integer(province_stats_2024$code)), , drop = FALSE
]
geojson_area <- as.numeric(st_area(st_transform(geojson, 3405)))
expected_area <- as.numeric(st_area(st_transform(expected, 3405)))
geojson_bbox <- t(vapply(st_geometry(geojson), st_bbox, numeric(4)))
expected_bbox <- t(vapply(st_geometry(expected), st_bbox, numeric(4)))

stopifnot(
  nrow(geojson) == 34L,
  nrow(stats) == 34L,
  identical(geojson$code, expected$code),
  identical(stats$code, expected$code),
  identical(geojson$name_vi, expected$name_vi),
  identical(geojson$name_en, expected$name_en),
  identical(geojson$type, expected$type),
  isTRUE(all.equal(stats, expected_stats, check.attributes = FALSE)),
  max(abs(geojson_area - expected_area) / expected_area) < 0.000001,
  max(abs(geojson_bbox - expected_bbox)) < 0.000001,
  identical(st_crs(geojson)$epsg, 4326L),
  !any(st_is_empty(geojson)),
  all(stats$year == 2024L),
  file.info(file.path(output_dir, "grdp-per-capita-2024.svg"))$size < 500000L
)

manifest <- readLines(file.path(output_dir, "checksums.md5"), warn = FALSE)
parts <- strsplit(manifest, " \\*")
recorded <- vapply(parts, `[[`, character(1), 1L)
paths <- file.path(output_dir, vapply(parts, `[[`, character(1), 2L))
stopifnot(identical(recorded, unname(tools::md5sum(paths))))

message("Verified 34 boundaries, 34 statistic rows, WGS84, SVG size, and checksums.")
