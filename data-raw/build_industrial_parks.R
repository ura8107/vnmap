# Build the bundled industrial-park layer from a dated OpenStreetMap snapshot.
# Set VNMAP_OSM_FILE to reuse a saved Overpass JSON response.

if (!requireNamespace("sf", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Packages 'sf' and 'jsonlite' are required.")
}

snapshot_date <- as.Date("2026-08-11")
official_established_baseline <- 478L
input <- Sys.getenv("VNMAP_OSM_FILE", unset = "")
if (!nzchar(input)) {
  snapshot <- "data-raw/source/osm-industrial-parks-2026-08-11.json.gz"
  if (file.exists(snapshot)) input <- snapshot
}
if (!nzchar(input)) {
  input <- tempfile(fileext = ".json")
  query <- paste0(
    '[out:json][timeout:150];area["ISO3166-1"="VN"]',
    '[admin_level=2]->.vn;nwr(area.vn)["name"~',
    '"(Khu công nghiệp|Khu cong nghiep|Industrial Park|Industrial Zone|',
    'Export Processing Zone|KCN | IZ$)",i];out center tags geom;'
  )
  endpoint <- "https://overpass.kumi.systems/api/interpreter"
  utils::download.file(paste0(endpoint, "?data=", utils::URLencode(query)), input,
                       mode = "wb", quiet = TRUE)
}

con <- if (grepl("\\.gz$", input)) gzfile(input, "rt") else file(input, "rt")
raw <- jsonlite::fromJSON(paste(readLines(con, warn = FALSE), collapse = ""),
                          simplifyVector = FALSE)$elements
close(con)
tag <- function(x, key, default = NA_character_) {
  value <- x$tags[[key]]
  if (is.null(value)) default else as.character(value)
}
eligible <- vapply(raw, function(x) {
  identical(tag(x, "landuse", ""), "industrial") ||
    identical(tag(x, "industrial", ""), "industrial_park")
}, logical(1))
names_normalized <- vapply(raw, function(x) {
  tolower(stringi::stri_trans_general(tag(x, "name", ""), "Latin-ASCII"))
}, "")
# Remove named facilities that merely mention their containing industrial park,
# plus anonymous labels that cannot serve as a stable park record.
eligible <- eligible & !grepl("^(nha may|tram |cong )", names_normalized) &
  !names_normalized %in% c("khu cong nghiep", "kcn")
raw <- raw[eligible]

make_geometry <- function(x) {
  if (identical(x$type, "way") && length(x$geometry) >= 4L) {
    xy <- do.call(rbind, lapply(x$geometry, function(p) c(p$lon, p$lat)))
    if (!all(xy[1, ] == xy[nrow(xy), ])) xy <- rbind(xy, xy[1, ])
    return(sf::st_polygon(list(xy)))
  }
  lon <- if (!is.null(x$lon)) x$lon else if (!is.null(x$center$lon)) {
    x$center$lon
  } else mean(c(x$bounds$minlon, x$bounds$maxlon))
  lat <- if (!is.null(x$lat)) x$lat else if (!is.null(x$center$lat)) {
    x$center$lat
  } else mean(c(x$bounds$minlat, x$bounds$maxlat))
  sf::st_point(c(lon, lat))
}

geometry <- sf::st_sfc(lapply(raw, make_geometry), crs = 4326)
parks <- sf::st_sf(
  id = vapply(raw, function(x) paste0("osm_", x$type, "_", x$id), ""),
  name_vi = vapply(raw, tag, "", key = "name"),
  name_en = vapply(raw, tag, "", key = "name:en"),
  aliases = vapply(raw, function(x) paste(unique(na.omit(c(
    tag(x, "name", NA_character_), tag(x, "name:en", NA_character_),
    tag(x, "alt_name", NA_character_), tag(x, "short_name", NA_character_)
  ))), collapse = "|"), ""),
  status = vapply(raw, function(x) {
    if (tag(x, "construction", "") != "" || tag(x, "landuse", "") == "construction")
      "under_construction" else "unknown"
  }, ""),
  developer = vapply(raw, tag, "", key = "operator"),
  source_url = vapply(raw, function(x) paste0("https://www.openstreetmap.org/", x$type, "/", x$id), ""),
  source_date = as.Date(rep(NA_character_, length(raw))),
  verified_on = rep(snapshot_date, length(raw)),
  geometry = geometry
)
parks$name_en[!nzchar(parks$name_en)] <- NA_character_
parks$developer[!nzchar(parks$developer)] <- NA_character_
parks <- sf::st_make_valid(parks)
gtype <- tolower(as.character(sf::st_geometry_type(parks)))
parks$geometry_type <- ifelse(gtype %in% c("polygon", "multipolygon"), "polygon", "point")
parks$location_accuracy <- ifelse(parks$geometry_type == "polygon", "site", "locality")

current <- sf::st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
former <- sf::st_transform(readRDS("inst/extdata/provinces_63.rds"), 4326)
representative <- suppressWarnings(sf::st_point_on_surface(parks))
join_code <- function(boundaries) {
  hits <- sf::st_intersects(representative, boundaries)
  vapply(hits, function(i) if (length(i)) boundaries$code[i[1]] else NA_character_, "")
}
parks$province_code <- join_code(current)
parks$former_province_code <- join_code(former)
info <- readRDS("inst/extdata/provinces_info.rds")
parks$province_en <- info$name_en[match(parks$province_code, info$code)]
if (anyNA(parks$province_code)) stop("Some parks could not be assigned to a current province.")

area <- rep(NA_real_, nrow(parks))
is_polygon <- parks$geometry_type == "polygon"
area[is_polygon] <- as.numeric(sf::st_area(parks[is_polygon, ])) / 10000
parks$area_ha <- area
parks <- parks[!duplicated(parks$id), ]
parks <- parks[order(parks$province_code, parks$name_vi, parks$id), ]
parks <- parks[c(
  "id", "name_vi", "name_en", "aliases", "province_code", "province_en",
  "former_province_code", "status", "area_ha", "developer", "geometry_type",
  "location_accuracy", "source_url", "source_date", "verified_on", "geometry"
)]
sf::st_crs(parks) <- 4326

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(parks, "inst/extdata/industrial_parks.rds", compress = "xz")
audit <- data.frame(
  metric = c("official_established_baseline_2025", "mapped_snapshot_records",
             "unmapped_against_baseline", "polygon_records", "point_records"),
  value = c(official_established_baseline, nrow(parks),
            max(official_established_baseline - nrow(parks), 0L),
            sum(parks$geometry_type == "polygon"), sum(parks$geometry_type == "point"))
)
utils::write.csv(audit, "data-raw/industrial-parks-audit.csv", row.names = FALSE)
message("Built ", nrow(parks), " mapped parks; official baseline gap: ",
        official_established_baseline - nrow(parks), ".")
