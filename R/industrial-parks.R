#' Obtain industrial park map data
#'
#' Returns the national industrial-park registry with the best redistributable
#' geometry available for each park. Site boundaries are retained where
#' OpenStreetMap has drawn the park; the remaining parks are placed by a
#' representative point derived from a gate, bus stop, internal road or other
#' feature that names them.
#'
#' @param province Optional current or pre-2025 provincial identifiers.
#' @param status Optional status values: `"operational"`,
#'   `"under_construction"`, `"established_not_started"`, or `"unknown"`.
#' @param include Optional park identifiers or Vietnamese/English names.
#' @param geometry One of `"best"`, `"polygon"`, or `"point"`. `"point"`
#'   converts polygon sites to points guaranteed to lie on their surfaces.
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#' @param category Optional category values: `"industrial_park"`,
#'   `"export_processing_zone"`, `"high_tech_park"`, or `"industrial_cluster"`.
#' @param accuracy Optional location accuracy: `"site"` for records with a
#'   mapped boundary, `"locality"` for records placed by a nearby reference.
#' @return An `sf` object. See [industrial_parks_data] for data provenance.
#' @seealso [industrial_park_registry()], [industrial_park_coverage()]
#' @examples
#' parks <- industrial_parks(province = "Dong Nai")
#' points <- industrial_parks(geometry = "point", crs = 4326)
#'
#' # Only parks whose boundary is mapped.
#' sites <- industrial_parks(accuracy = "site")
#' @export
industrial_parks <- function(province = NULL, status = NULL, include = NULL,
                             geometry = c("best", "polygon", "point"),
                             crs = vnmap_crs(), category = NULL,
                             accuracy = NULL) {
  geometry <- match.arg(geometry)
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required to load industrial park geometry. ",
         "Install it with install.packages(\"sf\").", call. = FALSE)
  }
  file <- system.file("extdata", "industrial_parks.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled industrial park data could not be found.", call. = FALSE)
  parks <- .filter_parks(readRDS(file), province, status, category, accuracy, include)

  if (geometry == "polygon") {
    parks <- parks[parks$geometry_type == "polygon", , drop = FALSE]
    if (!nrow(parks)) {
      stop("No industrial parks matched the requested filters.", call. = FALSE)
    }
  } else if (geometry == "point" && nrow(parks)) {
    sf::st_geometry(parks) <- sf::st_geometry(
      suppressWarnings(sf::st_point_on_surface(parks))
    )
    parks$geometry_type <- "point"
  }
  sf::st_transform(parks, crs)
}

#' Add industrial parks to a ggplot map
#'
#' Creates `ggplot2` layers that can be added directly to [plot_vnmap()].
#' @inheritParams industrial_parks
#' @param data Optional industrial park `sf` object.
#' @param polygon_fill,polygon_colour Fill and outline colours for polygons.
#' @param point_colour Colour for representative points.
#' @param alpha Polygon opacity.
#' @param linewidth Polygon outline width.
#' @param point_size Point size.
#' @return A list of `ggplot2` layers.
#' @examples
#' plot_vnmap() + geom_industrial_parks(point_colour = "#b2182b")
#' @export
geom_industrial_parks <- function(data = NULL, province = NULL, status = NULL,
                                  include = NULL,
                                  geometry = c("best", "polygon", "point"),
                                  crs = vnmap_crs(), category = NULL,
                                  accuracy = NULL,
                                  polygon_fill = "#e69f00",
                                  polygon_colour = "#9a6700",
                                  point_colour = "#b2182b", alpha = 0.35,
                                  linewidth = 0.25, point_size = 1.5) {
  geometry <- match.arg(geometry)
  if (is.null(data)) {
    data <- industrial_parks(province, status, include, geometry, crs,
                             category, accuracy)
  } else {
    if (!inherits(data, "sf")) stop("`data` must be an sf object.", call. = FALSE)
    data <- sf::st_transform(data, crs)
    type <- tolower(as.character(sf::st_geometry_type(data)))
    if (geometry == "polygon") data <- data[type %in% c("polygon", "multipolygon"), , drop = FALSE]
    if (geometry == "point") {
      sf::st_geometry(data) <- sf::st_geometry(
        suppressWarnings(sf::st_point_on_surface(data))
      )
    }
  }
  type <- tolower(as.character(sf::st_geometry_type(data)))
  polygons <- data[type %in% c("polygon", "multipolygon"), , drop = FALSE]
  points <- data[type %in% c("point", "multipoint"), , drop = FALSE]
  layers <- list()
  if (nrow(polygons)) layers <- c(layers, list(ggplot2::geom_sf(
    data = polygons, inherit.aes = FALSE, fill = polygon_fill,
    colour = polygon_colour, alpha = alpha, linewidth = linewidth)))
  if (nrow(points)) layers <- c(layers, list(ggplot2::geom_sf(
    data = points, inherit.aes = FALSE, colour = point_colour, size = point_size)))
  layers
}
