#' Obtain industrial park map data
#'
#' Returns established Vietnamese industrial parks with the best redistributable
#' geometry available for each park. Polygon boundaries are retained where a
#' mapped site boundary is available; otherwise a representative point is used.
#'
#' @param province Optional current or pre-2025 provincial identifiers.
#' @param status Optional status values: `"operational"`,
#'   `"under_construction"`, `"established_not_started"`, or `"unknown"`.
#' @param include Optional park identifiers or Vietnamese/English names.
#' @param geometry One of `"best"`, `"polygon"`, or `"point"`. `"point"`
#'   converts polygon sites to points guaranteed to lie on their surfaces.
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#' @return An `sf` object. See [industrial_parks_data] for data provenance.
#' @examples
#' parks <- industrial_parks(province = "Dong Nai")
#' points <- industrial_parks(geometry = "point", crs = 4326)
#' @export
industrial_parks <- function(province = NULL, status = NULL, include = NULL,
                             geometry = c("best", "polygon", "point"),
                             crs = vnmap_crs()) {
  geometry <- match.arg(geometry)
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required to load industrial park geometry. ",
         "Install it with install.packages(\"sf\").", call. = FALSE)
  }
  file <- system.file("extdata", "industrial_parks.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled industrial park data could not be found.", call. = FALSE)
  parks <- readRDS(file)

  if (!is.null(province)) {
    current <- tryCatch(province_code(province), error = function(e) NULL)
    former <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
    if (is.null(current) && is.null(former)) {
      stop("Unknown province or municipality: ", paste(province, collapse = ", "), call. = FALSE)
    }
    keep <- rep(FALSE, nrow(parks))
    if (!is.null(current)) keep <- keep | parks$province_code %in% current
    if (!is.null(former)) keep <- keep | parks$former_province_code %in% former
    parks <- parks[keep, , drop = FALSE]
  }
  if (!is.null(status)) {
    allowed <- c("operational", "under_construction",
                 "established_not_started", "unknown")
    bad <- setdiff(status, allowed)
    if (length(bad)) stop("Unknown industrial park status: ", paste(bad, collapse = ", "), call. = FALSE)
    parks <- parks[parks$status %in% status, , drop = FALSE]
  }
  if (!is.null(include)) {
    keys <- .vn_key(include)
    alias_hit <- vapply(strsplit(parks$aliases, "\\|"), function(x) {
      any(.vn_key(x) %in% keys)
    }, logical(1))
    keep <- .vn_key(parks$id) %in% keys | .vn_key(parks$name_vi) %in% keys |
      .vn_key(parks$name_en) %in% keys | alias_hit
    parks <- parks[keep, , drop = FALSE]
  }
  if (geometry == "polygon") {
    parks <- parks[parks$geometry_type == "polygon", , drop = FALSE]
  } else if (geometry == "point" && nrow(parks)) {
    sf::st_geometry(parks) <- sf::st_geometry(
      suppressWarnings(sf::st_point_on_surface(parks))
    )
    parks$geometry_type <- "point"
  }
  if (!nrow(parks)) stop("No industrial parks matched the requested filters.", call. = FALSE)
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
                                  crs = vnmap_crs(),
                                  polygon_fill = "#e69f00",
                                  polygon_colour = "#9a6700",
                                  point_colour = "#b2182b", alpha = 0.35,
                                  linewidth = 0.25, point_size = 1.5) {
  geometry <- match.arg(geometry)
  if (is.null(data)) {
    data <- industrial_parks(province, status, include, geometry, crs)
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
