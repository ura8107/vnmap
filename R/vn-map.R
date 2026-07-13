#' Obtain Viet Nam map data
#'
#' @param geography Either `"provinces"` (the 34 units effective from July
#'   2025) or `"provinces_63"` (the pre-July 2025 units).
#' @param include Optional names or codes of units to retain.
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#' @return An `sf` object.
#' @export
vn_map <- function(geography = c("provinces", "provinces_63"),
                   include = NULL, crs = vnmap_crs()) {
  geography <- match.arg(geography)
  file <- system.file("extdata", paste0(geography, ".rds"), package = "vnmap")
  if (!nzchar(file)) stop("Bundled map data could not be found.", call. = FALSE)
  map <- readRDS(file)
  if (!is.null(include)) {
    codes <- province_code(include, geography = geography)
    map <- map[map$code %in% codes, , drop = FALSE]
  }
  sf::st_transform(map, crs)
}

#' Coordinate reference system used by vnmap
#'
#' EPSG:3405 is the VN-2000 / UTM zone 48N projected CRS.
#' @return An `sf` CRS object.
#' @export
vnmap_crs <- function() sf::st_crs(3405)

