#' Obtain transport and logistics infrastructure
#'
#' @param type Optional values among `"port"`, `"aerodrome"`,
#'   `"border_control"`, `"expressway"`, `"national_highway"`, and `"railway"`.
#' @param status Optional lifecycle status. Supported values are
#'   `"operational"`, `"under_construction"`, `"planned"`, `"disused"`,
#'   `"abandoned"`, and `"unknown"`.
#' @param class Optional facility subclass, such as `"military_aerodrome"`,
#'   `"fishing_port"`, `"rail_yard"`, or `"rail_siding"`.
#' @param service Optional service classification, such as
#'   `"commercial_service_candidate"`, `"service=yard"`, or `"usage=main"`.
#' @param province Optional current province names or codes.
#' @param include Optional infrastructure IDs or names.
#' @param geometry `"any"`, `"point"`, or `"line"`.
#' @param crs Output CRS.
#' @return An `sf` object containing point and line geometry.
#' @details Coordinates are a pinned ODbL OpenStreetMap snapshot, not an
#'   official register. Status is classified only when lifecycle tags state it;
#'   otherwise it is `"unknown"`. No legal opening date is inferred.
#'   `"aerodrome"` does not imply scheduled commercial service, and `"port"`
#'   does not imply a seaport. Consult `infrastructure_class`, `status_source`,
#'   `location_accuracy`, and the retained raw OSM tag columns.
#'
#'   Trunk lines come from the checksum-pinned Geofabrik Vietnam OSM extract.
#'   They are generalized to 100 metres for statistical graphics. Lifecycle
#'   status is never inferred from road class or map presence.
#'   Facility aliases and nearby border-control components are reconciled to
#'   entity IDs. Points just outside generalized land geometry are retained only
#'   within 15 km and identified in `country_relation`.
#'   `province_code` is a scalar nearest-parent code for points only. It is `NA`
#'   for lines, whose intersected parents are listed in pipe-delimited
#'   `province_codes`. Province filtering always uses geometry intersection;
#'   the point code is only a fallback for flagged near-boundary facilities.
#' @source OpenStreetMap contributors, Open Database License (ODbL) 1.0,
#'   <https://www.openstreetmap.org/copyright>. The facility snapshot has OSM
#'   base timestamp 9 July 2026 and retrieval date 11 August 2026. Network lines
#'   use the checksum-pinned Geofabrik Viet Nam extract dated 10 August 2026.
#' @examples
#' infrastructure(type = "aerodrome", province = "Ha Noi")
#' @export
infrastructure <- function(type = NULL, status = NULL, province = NULL,
                           include = NULL, class = NULL, service = NULL,
                           geometry = c("any", "point", "line"),
                           crs = vnmap_crs()) {
  geometry <- match.arg(geometry)
  if (!requireNamespace("sf", quietly = TRUE)) stop("Package 'sf' is required.", call. = FALSE)
  file <- system.file("extdata", "infrastructure.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled infrastructure data could not be found.", call. = FALSE)
  x <- readRDS(file)
  allowed_type <- c("port", "aerodrome", "border_control", "expressway",
                    "national_highway", "railway")
  if (!is.null(type)) {
    bad <- setdiff(type, allowed_type)
    if (length(bad)) stop("Unknown infrastructure type: ", paste(bad, collapse = ", "), call. = FALSE)
    x <- x[x$infrastructure_type %in% type, ]
  }
  if (!is.null(status)) {
    bad <- setdiff(status, c("operational", "under_construction", "planned", "disused", "abandoned", "unknown"))
    if (length(bad)) stop("Unknown infrastructure status: ", paste(bad, collapse = ", "), call. = FALSE)
    x <- x[x$status %in% status, ]
  }
  if (!is.null(class)) {
    if (!"infrastructure_class" %in% names(x))
      stop("This snapshot does not contain facility subclasses.", call. = FALSE)
    known <- unique(x$infrastructure_class)
    bad <- setdiff(class, known)
    if (length(bad)) stop("Unknown infrastructure class: ", paste(bad, collapse = ", "), call. = FALSE)
    x <- x[x$infrastructure_class %in% class, ]
  }
  if (!is.null(service)) {
    known <- unique(x$service_type)
    bad <- setdiff(service, known)
    if (length(bad)) stop("Unknown infrastructure service: ", paste(bad, collapse = ", "), call. = FALSE)
    x <- x[x$service_type %in% service, ]
  }
  if (!is.null(province)) {
    x <- .filter_infrastructure_province(x, province)
  }
  if (!is.null(include)) {
    key <- .vn_key(include)
    alias_hit <- vapply(x$aliases, function(value) {
      any(.vn_key(strsplit(value, "|", fixed = TRUE)[[1L]]) %in% key)
    }, logical(1))
    x <- x[.vn_key(x$id) %in% key | .vn_key(x$name_vi) %in% key |
             .vn_key(x$name_en) %in% key | alias_hit, ]
  }
  gt <- tolower(as.character(sf::st_geometry_type(x)))
  if (geometry == "point") x <- x[gt %in% c("point", "multipoint"), ]
  if (geometry == "line") x <- x[gt %in% c("linestring", "multilinestring"), ]
  if (!nrow(x)) stop("No infrastructure matched the requested filters.", call. = FALSE)
  sf::st_transform(x, crs)
}

.filter_infrastructure_province <- function(x, province) {
  code <- province_code(province)
  selected <- vn_map(include = code, crs = sf::st_crs(x))
  spatial_hit <- lengths(sf::st_intersects(
    sf::st_geometry(x), sf::st_union(sf::st_geometry(selected)))) > 0L
  gt <- tolower(as.character(sf::st_geometry_type(x)))
  point <- gt %in% c("point", "multipoint")
  assigned_hit <- if ("province_code" %in% names(x))
    point & x$province_code %in% code else rep(FALSE, nrow(x))
  x[spatial_hit | assigned_hit, ]
}

#' Add infrastructure to a ggplot map
#' @inheritParams infrastructure
#' @param data Optional infrastructure `sf` object.
#' @param point_colour,line_colour Colours for points and lines.
#' @param point_size,line_width Sizes for points and lines.
#' @param mapping Optional aesthetics. When omitted, facility points use shape
#'   and network lines use linetype to distinguish `infrastructure_type`.
#' @param inherit.aes Whether to inherit aesthetics from the parent plot.
#' @param show.legend Whether this layer should appear in legends.
#' @param na.rm Whether missing values are silently removed.
#' @return A list of ggplot2 layers.
#' @export
geom_infrastructure <- function(data = NULL, type = NULL, status = NULL,
                                province = NULL, include = NULL, class = NULL,
                                service = NULL,
                                geometry = c("any", "point", "line"),
                                crs = vnmap_crs(), point_colour = "#2166ac",
                                line_colour = "#4d4d4d", point_size = 1.8,
                                line_width = 0.5, mapping = NULL,
                                inherit.aes = FALSE, show.legend = NA, na.rm = FALSE) {
  geometry <- match.arg(geometry)
  if (is.null(data)) data <- infrastructure(type, status, province, include,
                                             class, service, geometry, crs)
  if (!inherits(data, "sf")) stop("`data` must be an sf object.", call. = FALSE)
  if (!is.null(type)) data <- data[data$infrastructure_type %in% type, ]
  if (!is.null(status)) data <- data[data$status %in% status, ]
  if (!is.null(class)) {
    if (!"infrastructure_class" %in% names(data))
      stop("`data` has no `infrastructure_class` column.", call. = FALSE)
    data <- data[data$infrastructure_class %in% class, ]
  }
  if (!is.null(service)) {
    if (!"service_type" %in% names(data))
      stop("`data` has no `service_type` column.", call. = FALSE)
    data <- data[data$service_type %in% service, ]
  }
  if (!is.null(province)) {
    data <- .filter_infrastructure_province(data, province)
  }
  if (!is.null(include)) {
    k <- .vn_key(include)
    aliases <- if ("aliases" %in% names(data)) data$aliases else rep("", nrow(data))
    alias_hit <- vapply(aliases, function(value) {
      any(.vn_key(strsplit(value, "|", fixed = TRUE)[[1L]]) %in% k)
    }, logical(1))
    data <- data[.vn_key(data$id) %in% k | .vn_key(data$name_vi) %in% k |
                   .vn_key(data$name_en) %in% k | alias_hit, ]
  }
  data <- sf::st_transform(data, crs)
  gt <- tolower(as.character(sf::st_geometry_type(data)))
  points <- data[gt %in% c("point", "multipoint"), ]
  lines <- data[gt %in% c("linestring", "multilinestring"), ]
  if (geometry == "point") lines <- lines[FALSE, ]
  if (geometry == "line") points <- points[FALSE, ]
  layers <- list()
  line_mapping <- if (is.null(mapping) && "infrastructure_type" %in% names(lines))
    ggplot2::aes(linetype = .data$infrastructure_type) else if (is.null(mapping)) ggplot2::aes() else mapping
  point_mapping <- if (is.null(mapping) && "infrastructure_type" %in% names(points))
    ggplot2::aes(shape = .data$infrastructure_type) else if (is.null(mapping)) ggplot2::aes() else mapping
  if (nrow(lines)) layers <- c(layers, list(ggplot2::geom_sf(
    data = lines, mapping = line_mapping, inherit.aes = inherit.aes, colour = line_colour,
    linewidth = line_width, show.legend = show.legend, na.rm = na.rm)))
  if (nrow(points)) layers <- c(layers, list(ggplot2::geom_sf(
    data = points, mapping = point_mapping, inherit.aes = inherit.aes, colour = point_colour,
    size = point_size, show.legend = show.legend, na.rm = na.rm)))
  layers
}
