#' Plot a map of Viet Nam
#'
#' Creates a `ggplot2` outline map or choropleth from the bundled provincial
#' boundaries. Statistical values are joined using names, aliases, official
#' codes, or historical codes appropriate to the selected geography.
#'
#' @param geography Either `"provinces"` for the current 34-unit geography or
#'   `"provinces_63"` for the historical 63-unit geography.
#' @param data Optional data frame containing one row per administrative unit.
#' @param values Character scalar naming the column in `data` mapped to the
#'   polygon fill aesthetic. Required when `data` is supplied.
#' @param id Character scalar naming the column in `data` containing province
#'   or municipality names, aliases, two-digit codes, or ISO codes.
#' @param include Optional character vector of unit names or codes to display.
#' @param region Optional character vector of socio-economic region codes
#'   (`"RRD"`, `"NMM"`, `"NCC"`, `"CH"`, `"SE"`, `"MRD"`) or English region
#'   names. Units matching either `include` or `region` are displayed.
#' @param labels Logical; if `TRUE`, add Vietnamese names at points guaranteed
#'   to lie inside each geometry.
#' @param insets Controls enlarged inset panels for small units that are hard
#'   to see at national scale. `FALSE` (default) draws none; `TRUE` enlarges
#'   the centrally governed municipalities; a character vector of names or
#'   codes enlarges those specific units. This feature is experimental.
#' @param ... Passed to [ggplot2::geom_sf()].
#'
#' @return A `ggplot` object. Add scales, titles, annotations, and themes using
#'   ordinary `ggplot2` layers.
#'
#' @details When `data` is supplied, units without a matching row receive
#'   `NA` as the fill value and are handled by the chosen fill scale. Duplicate
#'   identifiers in `data` are rejected because a polygon can have only one
#'   fill value. Unit identifiers are normalized by [province_code()].
#'
#'   Arguments such as `color`, `linewidth`, and `alpha` are passed through to
#'   [ggplot2::geom_sf()]. Labels use `name_vi` and may overlap on dense maps;
#'   `check_overlap = TRUE` suppresses some overlapping labels.
#'
#'   Insets are drawn as scaled copies placed in the right margin of the map
#'   and reuse the same fill mapping and styling as the main layer.
#'
#' @seealso [vn_map()], [province_code()], [ggplot2::geom_sf()]
#'
#' @examples
#' plot_vnmap(color = "white", linewidth = 0.2)
#'
#' values <- transform(province_info(), value = seq_len(34))
#' plot_vnmap(
#'   data = values,
#'   values = "value",
#'   id = "code",
#'   color = "white",
#'   linewidth = 0.2
#' ) + ggplot2::scale_fill_viridis_c(name = "Example")
#'
#' plot_vnmap(region = "MRD", labels = TRUE)
#'
#' plot_vnmap(
#'   geography = "provinces_63",
#'   include = c("Ha Noi", "Hai Phong", "Quang Ninh"),
#'   labels = TRUE
#' )
#' @export
plot_vnmap <- function(geography = c("provinces", "provinces_63"), data = NULL,
                       values = NULL, id = "code", include = NULL,
                       region = NULL, labels = FALSE, insets = FALSE, ...) {
  geography <- match.arg(geography)
  map <- vn_map(geography, include = include, region = region)
  has_data <- !is.null(data)
  if (has_data) {
    if (is.null(values) || !values %in% names(data)) stop("`values` must name a column in `data`.", call. = FALSE)
    if (!id %in% names(data)) stop("`id` must name a column in `data`.", call. = FALSE)
    data$.vnmap_code <- province_code(data[[id]], geography)
    if (anyDuplicated(data$.vnmap_code)) stop("`data` contains duplicate provincial units.", call. = FALSE)
    idx <- match(map$code, data$.vnmap_code)
    map$.vnmap_value <- data[[values]][idx]
  }
  p <- ggplot2::ggplot(map)
  if (has_data) p <- p + ggplot2::geom_sf(ggplot2::aes(fill = .data$.vnmap_value), ...)
  else p <- p + ggplot2::geom_sf(...)
  if (!isFALSE(insets)) p <- .add_insets(p, map, insets, geography, has_data, ...)
  if (isTRUE(labels)) {
    pts <- suppressWarnings(sf::st_point_on_surface(map))
    p <- p + ggplot2::geom_sf(data = pts, ggplot2::aes(label = .data$name_vi),
                              geom = "text", size = 2.5, check_overlap = TRUE)
  }
  p + ggplot2::coord_sf(datum = NA) + ggplot2::theme_void()
}

# Add scaled inset copies of selected units to the right margin. Experimental.
.add_insets <- function(p, map, insets, geography, has_data, ..., scale = 2.5) {
  units <- if (isTRUE(insets)) map$code[map$type == "municipality"] else province_code(insets, geography)
  units <- intersect(units, map$code)
  if (!length(units)) return(p)
  bb <- sf::st_bbox(map)
  width <- unname(bb["xmax"] - bb["xmin"])
  height <- unname(bb["ymax"] - bb["ymin"])
  crs <- sf::st_crs(map)
  step <- height / length(units)
  x0 <- unname(bb["xmax"]) + 0.20 * width
  for (i in seq_along(units)) {
    unit <- map[map$code == units[i], , drop = FALSE]
    g <- sf::st_geometry(unit)[[1]]
    ctr <- sf::st_geometry(suppressWarnings(sf::st_centroid(unit)))[[1]]
    target <- sf::st_point(c(x0, unname(bb["ymax"]) - (i - 0.5) * step))
    moved <- (g - ctr) * scale + target
    inset <- sf::st_set_geometry(unit, sf::st_sfc(moved, crs = crs))
    if (has_data) p <- p + ggplot2::geom_sf(data = inset, ggplot2::aes(fill = .data$.vnmap_value), ...)
    else p <- p + ggplot2::geom_sf(data = inset, ...)
  }
  p
}
