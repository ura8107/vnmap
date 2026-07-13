#' Obtain Viet Nam map data
#'
#' Returns a simple-features boundary layer for the provincial-level
#' administrative units of Viet Nam. The current layer contains the 34 units
#' effective from 1 July 2025. A 63-unit layer is retained for data collected
#' under the immediately preceding geography.
#'
#' @param geography Either `"provinces"` (the 34 units effective from July
#'   2025) or `"provinces_63"` (the pre-July 2025 units).
#' @param include Optional character vector of names, aliases, official
#'   two-digit codes, or ISO 3166-2 codes to retain. Vietnamese names may be
#'   supplied with or without diacritics.
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#'
#' @return An `sf` object with one row per unit and the following columns:
#'   `code`, `iso`, `name_vi`, `name_en`, `type`, and `geometry`. Current units
#'   created by the 2025 reform have `NA` in `iso` where no code is bundled.
#'
#' @details The bundled geometry is projected to EPSG:3405 by default. Pass a
#'   different EPSG code or an `sf` CRS object to `crs` when another projection
#'   is required. Filtering happens before transformation.
#'
#'   The 34-unit layer was constructed by dissolving historical provincial
#'   boundaries according to Decision 19/2025/QD-TTg. The source geometry is
#'   generalized and intended for statistical graphics, not surveying,
#'   navigation, or legal boundary determinations.
#'
#' @seealso [plot_vnmap()], [province_code()], [province_info()]
#'
#' @examples
#' map <- vn_map()
#' nrow(map)
#' names(map)
#'
#' north <- vn_map(include = c("Ha Noi", "Bac Ninh"))
#' nrow(north)
#'
#' historical <- vn_map("provinces_63", crs = 4326)
#' sf::st_crs(historical)$input
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
#'
#' @return An `sf` CRS object.
#'
#' @details All bundled geometries are returned in this projected CRS unless a
#'   different value is supplied to the `crs` argument of [vn_map()]. Using a
#'   projected CRS keeps distances and polygon rendering stable for national
#'   statistical maps.
#'
#' @seealso [vn_map()], [sf::st_crs()]
#'
#' @examples
#' vnmap_crs()
#' @export
vnmap_crs <- function() sf::st_crs(3405)
