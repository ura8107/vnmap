args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[[1L]] else "app-assets/vietnam-calendar"

Sys.setenv(TZ = "UTC")
Sys.setlocale("LC_NUMERIC", "C")
options(scipen = 999, digits = 15)

suppressPackageStartupMessages({
  library(ggplot2)
  library(sf)
  library(vnmap)
})

if (!requireNamespace("svglite", quietly = TRUE)) {
  stop("Package `svglite` is required to build the demo SVG.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

atomic_replace <- function(from, to) {
  if (!file.copy(from, to, overwrite = TRUE, copy.mode = FALSE)) {
    stop("Could not write ", to, call. = FALSE)
  }
  unlink(from)
}

# Boundary export: use the installed package's public API, preserve its field
# order, force web-standard longitude/latitude, and sort by numeric code.
boundaries <- vn_map(crs = 4326)
boundaries <- boundaries[order(as.integer(boundaries$code)),
                         c("code", "iso", "name_vi", "name_en", "type", "geometry")]
stopifnot(nrow(boundaries) == 34L, !anyDuplicated(boundaries$code))

geojson_path <- file.path(output_dir, "vietnam-provinces-34.geojson")
geojson_tmp <- tempfile(fileext = ".geojson", tmpdir = output_dir)
st_write(
  boundaries,
  geojson_tmp,
  layer = "vietnam-provinces-34",
  driver = "GeoJSON",
  layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6"),
  quiet = TRUE
)
atomic_replace(geojson_tmp, geojson_path)

# Tabular export: retain the exact package dataset schema. Quoting every
# character field makes leading-zero codes and UTF-8 names unambiguous.
data("province_stats_2024", package = "vnmap", envir = environment())
stats <- province_stats_2024[order(as.integer(province_stats_2024$code)), , drop = FALSE]
stopifnot(nrow(stats) == 34L, identical(stats$code, boundaries$code))

csv_path <- file.path(output_dir, "province-stats-2024.csv")
csv_tmp <- tempfile(fileext = ".csv", tmpdir = output_dir)
write.csv(stats, csv_tmp, row.names = FALSE, na = "", fileEncoding = "UTF-8")
atomic_replace(csv_tmp, csv_path)

# Demo contract: compare 2024 GRDP per capita across all 34 units using a
# single-root sequential palette. The unit, year, and aggregation caveat are
# visible in the subtitle/caption.
demo <- plot_vnmap(
  data = stats,
  values = "grdp_per_capita_million_vnd",
  id = "code",
  color = "#ffffff",
  linewidth = 0.18
) +
  scale_fill_gradient(
    low = "#dbeafe",
    high = "#1d4ed8",
    name = "Million VND\nper person"
  ) +
  labs(
    title = "Viet Nam GRDP per capita",
    subtitle = "34 current provincial units; preliminary 2024 values",
    caption = "Source: NSO Viet Nam; merged-unit estimates from vnmap"
  ) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.title = element_text(color = "#172033", face = "bold", size = 15),
    plot.subtitle = element_text(color = "#475569", size = 9),
    plot.caption = element_text(color = "#64748b", size = 7),
    legend.position = "bottom",
    legend.title = element_text(color = "#334155", size = 8),
    legend.text = element_text(color = "#475569", size = 7),
    plot.margin = margin(10, 12, 8, 12)
  )

svg_path <- file.path(output_dir, "grdp-per-capita-2024.svg")
svg_tmp <- tempfile(fileext = ".svg", tmpdir = output_dir)
svglite::svglite(svg_tmp, width = 5.2, height = 6.4, bg = "white", fix_text_size = FALSE)
print(demo)
grDevices::dev.off()
atomic_replace(svg_tmp, svg_path)

artifact_names <- basename(c(geojson_path, csv_path, svg_path))
checksums <- unname(tools::md5sum(file.path(output_dir, artifact_names)))
writeLines(
  paste(checksums, paste0("*", artifact_names)),
  file.path(output_dir, "checksums.md5"),
  useBytes = TRUE
)

message("Built ", length(artifact_names), " vietnam-calendar assets in ", output_dir)
