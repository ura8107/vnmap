#' Obtain an evidence-graded economic and policy zone catalogue
#'
#' Returns a conservative catalogue of Vietnamese place-based policy zones.
#' Industrial parks are deliberately excluded; use [industrial_parks()] for
#' those. Coastal and border-gate catalogues reconcile current officially
#' reported national counts, but names without row-level legal instruments are
#' labelled as count-reconciled candidates. EPZ scope is Ho Chi Minh City, not
#' national. Inspect `baseline_scope` and `baseline_status` in
#' the build audit before population-level inference. Some legal economic zones
#' contain industrial parks, but the zone row is not an industrial-park row.
#'
#' @param province Optional current or pre-2025 province identifiers.
#' @param type Optional zone types: `"coastal_economic_zone"`,
#'   `"border_gate_economic_zone"`, `"export_processing_zone"`, or
#'   `"national_high_tech_park"`.
#' @param status Optional legal-status values: `"established"` or
#'   `"candidate_or_count_reconciled"`. The latter means that an official
#'   aggregate count or non-establishment reference supports inclusion, but a
#'   row-level establishment instrument has not been verified.
#' @param include Optional IDs, Vietnamese/English names, or aliases.
#' @param as_of Optional date. Zones whose verified establishment effective
#'   date is later than this date are excluded.
#' @param include_unknown With `as_of`, retain records whose establishment
#'   effective date is unknown. Defaults to `TRUE` so catalogue records are not
#'   silently lost; set to `FALSE` for strict dated panels.
#' @param geometry One of `"best"`, `"polygon"`, or `"point"`. `"point"`
#'   converts polygon zones to an interior point. The initial conservative
#'   snapshot contains deterministic province-only representative points.
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#' @return An `sf` object in `crs`.
#' @examples
#' economic_zones(type = "national_high_tech_park")
#' economic_zones(province = "Ho Chi Minh City", as_of = "2010-01-01")
#' @export
economic_zones <- function(province = NULL, type = NULL, status = NULL,
                           include = NULL, as_of = NULL, include_unknown = TRUE,
                           geometry = c("best", "polygon", "point"),
                           crs = vnmap_crs()) {
  geometry <- match.arg(geometry)
  if (!requireNamespace("sf", quietly = TRUE))
    stop("Package 'sf' is required to load economic-zone geometry.", call. = FALSE)
  file <- system.file("extdata", "economic_zones.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled economic-zone data could not be found.", call. = FALSE)
  zones <- readRDS(file)
  allowed_types <- c("coastal_economic_zone", "border_gate_economic_zone",
                     "export_processing_zone", "national_high_tech_park")
  allowed_status <- c("established", "candidate_or_count_reconciled")
  if (!is.null(type) && length(bad <- setdiff(type, allowed_types)))
    stop("Unknown economic-zone type: ", paste(bad, collapse = ", "), call. = FALSE)
  if (!is.null(status) && length(bad <- setdiff(status, allowed_status)))
    stop("Unknown economic-zone status: ", paste(bad, collapse = ", "), call. = FALSE)
  if (!is.null(province)) {
    current <- tryCatch(province_code(province), error = function(e) NULL)
    former <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
    if (is.null(current) && is.null(former))
      stop("Unknown province or municipality: ", paste(province, collapse = ", "), call. = FALSE)
    keep <- rep(FALSE, nrow(zones))
    if (!is.null(current)) keep <- keep | zones$province_code %in% current
    if (!is.null(former)) keep <- keep | zones$former_province_code %in% former
    zones <- zones[keep, , drop = FALSE]
  }
  if (!is.null(type)) zones <- zones[zones$zone_type %in% type, , drop = FALSE]
  if (!is.null(status)) zones <- zones[zones$legal_status %in% status, , drop = FALSE]
  if (!is.null(include)) {
    keys <- .vn_key(include)
    aliases <- vapply(strsplit(zones$aliases, "\\|"),
                      function(x) any(.vn_key(x) %in% keys), logical(1))
    keep <- .vn_key(zones$id) %in% keys | .vn_key(zones$name_vi) %in% keys |
      .vn_key(zones$name_en) %in% keys | aliases
    zones <- zones[keep, , drop = FALSE]
  }
  if (!is.null(as_of)) {
    as_of <- tryCatch(as.Date(as_of), error = function(e) as.Date(NA))
    if (length(as_of) != 1L || is.na(as_of)) stop("`as_of` must be one valid date.", call. = FALSE)
    known <- !is.na(zones$established_effective_date)
    keep <- known & zones$established_effective_date <= as_of
    if (isTRUE(include_unknown)) keep <- keep | !known
    zones <- zones[keep, , drop = FALSE]
  }
  if (geometry == "polygon") zones <- zones[zones$geometry_type == "polygon", , drop = FALSE]
  if (geometry == "point" && nrow(zones)) {
    sf::st_geometry(zones) <- sf::st_geometry(suppressWarnings(sf::st_point_on_surface(zones)))
    zones$geometry_type <- "point"
  }
  if (!nrow(zones)) stop("No economic zones matched the requested filters.", call. = FALSE)
  if (any(!zones$geometry_available) &&
      !isTRUE(getOption("vnmap.suppress_fallback_warning"))) {
    warning("Economic-zone fallback points identify the associated province only; ",
            "they are not zone or site locations. Inspect `geometry_available` ",
            "and `location_accuracy`.", call. = FALSE)
  }
  sf::st_transform(zones, crs)
}

#' Add economic and policy zones to a ggplot map
#'
#' @inheritParams economic_zones
#' @param data Optional economic-zone `sf` object.
#' @param polygon_fill,polygon_colour Polygon colours.
#' @param point_colour Representative-point colour. Province-only fallback
#'   points use a cross (`shape = 4`) to distinguish them from site locations.
#' @param alpha Polygon opacity.
#' @param linewidth Polygon outline width.
#' @param point_size Representative-point size.
#' @return A list of `ggplot2` layers.
#' @examples
#' plot_vnmap() + geom_economic_zones(type = "national_high_tech_park")
#' @export
geom_economic_zones <- function(data = NULL, province = NULL, type = NULL,
                                status = NULL, include = NULL, as_of = NULL,
                                include_unknown = TRUE,
                                geometry = c("best", "polygon", "point"),
                                crs = vnmap_crs(), polygon_fill = "#6a51a3",
                                polygon_colour = "#3f007d", point_colour = "#54278f",
                                alpha = 0.3, linewidth = 0.3, point_size = 2) {
  geometry <- match.arg(geometry)
  if (is.null(data)) {
    data <- economic_zones(province, type, status, include, as_of,
                           include_unknown, geometry, crs)
  } else {
    if (!inherits(data, "sf")) stop("`data` must be an sf object.", call. = FALSE)
    # Apply the same public filters to supplied package-shaped data.
    allowed_types <- c("coastal_economic_zone", "border_gate_economic_zone",
                       "export_processing_zone", "national_high_tech_park")
    if (!is.null(type) && length(bad <- setdiff(type, allowed_types)))
      stop("Unknown economic-zone type: ", paste(bad, collapse = ", "), call. = FALSE)
    if (!is.null(type)) data <- data[data$zone_type %in% type, , drop = FALSE]
    allowed_status <- c("established", "candidate_or_count_reconciled")
    if (!is.null(status) && length(bad <- setdiff(status, allowed_status)))
      stop("Unknown economic-zone status: ", paste(bad, collapse = ", "), call. = FALSE)
    if (!is.null(status)) data <- data[data$legal_status %in% status, , drop = FALSE]
    if (!is.null(province)) {
      current <- tryCatch(province_code(province), error = function(e) NULL)
      former <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
      if (is.null(current) && is.null(former))
        stop("Unknown province or municipality: ", paste(province, collapse = ", "), call. = FALSE)
      keep <- rep(FALSE, nrow(data))
      if (!is.null(current)) keep <- keep | data$province_code %in% current
      if (!is.null(former)) keep <- keep | data$former_province_code %in% former
      data <- data[keep, , drop = FALSE]
    }
    if (!is.null(include)) {
      keys <- .vn_key(include)
      alias_hit <- vapply(strsplit(data$aliases, "\\|"),
                          function(x) any(.vn_key(x) %in% keys), logical(1))
      data <- data[.vn_key(data$id) %in% keys | .vn_key(data$name_vi) %in% keys |
                     .vn_key(data$name_en) %in% keys | alias_hit, , drop = FALSE]
    }
    if (!is.null(as_of)) {
      date <- tryCatch(as.Date(as_of), error = function(e) as.Date(NA))
      if (length(date) != 1L || is.na(date))
        stop("`as_of` must be one valid date.", call. = FALSE)
      known <- !is.na(data$established_effective_date)
      keep <- known & data$established_effective_date <= date
      if (isTRUE(include_unknown)) keep <- keep | !known
      data <- data[keep, , drop = FALSE]
    }
    supplied_type <- tolower(as.character(sf::st_geometry_type(data)))
    if (geometry == "polygon")
      data <- data[supplied_type %in% c("polygon", "multipolygon"), , drop = FALSE]
    if (geometry == "point" && nrow(data)) {
      sf::st_geometry(data) <- sf::st_geometry(
        suppressWarnings(sf::st_point_on_surface(data)))
      data$geometry_type <- "point"
    }
    if (!nrow(data)) stop("No economic zones matched the requested filters.", call. = FALSE)
    if (any(!data$geometry_available) &&
        !isTRUE(getOption("vnmap.suppress_fallback_warning"))) {
      warning("Economic-zone fallback points identify the associated province only; ",
              "they are not zone or site locations. Inspect `geometry_available` ",
              "and `location_accuracy`.", call. = FALSE)
    }
    data <- sf::st_transform(data, crs)
  }
  gtype <- tolower(as.character(sf::st_geometry_type(data)))
  polygons <- data[gtype %in% c("polygon", "multipolygon"), , drop = FALSE]
  points <- data[gtype %in% c("point", "multipoint"), , drop = FALSE]
  layers <- list()
  if (nrow(polygons)) layers <- c(layers, list(ggplot2::geom_sf(
    data = polygons, inherit.aes = FALSE, fill = polygon_fill,
    colour = polygon_colour, alpha = alpha, linewidth = linewidth)))
  if (nrow(points)) {
    fallback <- points[!points$geometry_available, , drop = FALSE]
    located <- points[points$geometry_available, , drop = FALSE]
    if (nrow(located)) layers <- c(layers, list(ggplot2::geom_sf(
      data = located, inherit.aes = FALSE, colour = point_colour, size = point_size)))
    if (nrow(fallback)) layers <- c(layers, list(ggplot2::geom_sf(
      data = fallback, inherit.aes = FALSE, colour = point_colour,
      shape = 4, size = point_size)))
  }
  layers
}
