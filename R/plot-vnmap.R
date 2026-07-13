#' Plot a map of Viet Nam
#'
#' @param geography Current 34-unit or historical 63-unit geography.
#' @param data Optional data frame containing a unit identifier and values.
#' @param values Column in `data` mapped to fill.
#' @param id Column in `data` containing province names or codes.
#' @param include Optional unit names or codes to display.
#' @param labels Add labels at points guaranteed to lie inside each geometry.
#' @param ... Passed to [ggplot2::geom_sf()].
#' @return A `ggplot` object.
#' @export
plot_vnmap <- function(geography = c("provinces", "provinces_63"), data = NULL,
                       values = NULL, id = "code", include = NULL,
                       labels = FALSE, ...) {
  geography <- match.arg(geography)
  map <- vn_map(geography, include)
  if (!is.null(data)) {
    if (is.null(values) || !values %in% names(data)) stop("`values` must name a column in `data`.", call. = FALSE)
    if (!id %in% names(data)) stop("`id` must name a column in `data`.", call. = FALSE)
    data$.vnmap_code <- province_code(data[[id]], geography)
    if (anyDuplicated(data$.vnmap_code)) stop("`data` contains duplicate provincial units.", call. = FALSE)
    idx <- match(map$code, data$.vnmap_code)
    map$.vnmap_value <- data[[values]][idx]
  }
  p <- ggplot2::ggplot(map)
  if (is.null(data)) p <- p + ggplot2::geom_sf(...)
  else p <- p + ggplot2::geom_sf(ggplot2::aes(fill = .data$.vnmap_value), ...)
  if (isTRUE(labels)) {
    pts <- suppressWarnings(sf::st_point_on_surface(map))
    p <- p + ggplot2::geom_sf(data = pts, ggplot2::aes(label = .data$name_vi),
                              geom = "text", size = 2.5, check_overlap = TRUE)
  }
  p + ggplot2::coord_sf(datum = NA) + ggplot2::theme_void()
}

