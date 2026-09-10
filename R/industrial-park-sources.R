#' Inspect complete industrial-park source lists and unresolved records
#'
#' Returns every row from the dated Invest Vietnam map feed and the KCN-KKT
#' discovery list, including rows without an accepted location. These are
#' source records, not unique parks: multiple records can link to one map ID.
#' The discovery list includes planned projects and does not verify legal
#' establishment or operational status. See `source_url`, `match_method`,
#' `legal_status`, and `reported_coordinate_check` before interpreting a row.
#'
#' @param source Optional exact source labels, as returned in the source column.
#' @param mapped Optional logical value: `TRUE` returns linked records,
#'   `FALSE` returns unresolved records, and `NULL` returns both.
#' @return A data frame. Coordinates are WGS84 longitude/latitude; unlinked
#'   records retain missing coordinates rather than province-centroid points.
#' @examples
#' remaining <- industrial_park_sources(mapped = FALSE)
#' head(remaining[c("name_vi", "source_url", "review_status")])
#' industrial_park_source_coverage()
#' @export
industrial_park_sources <- function(source = NULL, mapped = NULL) {
  path <- system.file("extdata", "industrial_park_sources.rds", package = "vnmap")
  if (!nzchar(path)) stop("Industrial park source catalogue is unavailable.", call. = FALSE)
  x <- readRDS(path)
  if (!is.null(source)) {
    if (anyNA(source) || !all(source %in% x$source)) stop("Unknown source label.", call. = FALSE)
    x <- x[x$source %in% source, , drop = FALSE]
  }
  if (!is.null(mapped)) {
    if (!is.logical(mapped) || length(mapped) != 1L || is.na(mapped)) {
      stop("`mapped` must be NULL, TRUE, or FALSE.", call. = FALSE)
    }
    x <- x[x$coordinate_available == mapped, , drop = FALSE]
  }
  rownames(x) <- NULL
  x
}

#' @rdname industrial_park_sources
#' @export
industrial_park_source_coverage <- function() {
  x <- industrial_park_sources()
  do.call(rbind, lapply(unique(x$source), function(s) {
    y <- x[x$source == s, ]
    data.frame(source = s, source_records = nrow(y),
      linked_records = sum(y$coordinate_available),
      unresolved_records = sum(!y$coordinate_available),
      distinct_linked_map_sites = length(unique(stats::na.omit(y$map_id))),
      retrieved_on = max(y$retrieved_on), stringsAsFactors = FALSE)
  }))
}
