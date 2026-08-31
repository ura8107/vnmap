#' Obtain the national industrial-park registry
#'
#' Returns the bundled registry of Vietnamese industrial parks as a plain data
#' frame, one row per park, without requiring `sf`. Every row carries a
#' representative `lon`/`lat`, the administrative units it falls in, and the
#' OpenStreetMap elements it was built from. Use [industrial_parks()] for the
#' same records with their boundaries attached.
#'
#' @param province Optional current or pre-2025 provincial identifiers.
#' @param status Optional status values: `"operational"`,
#'   `"under_construction"`, `"established_not_started"`, or `"unknown"`.
#' @param category Optional category values: `"industrial_park"`,
#'   `"export_processing_zone"`, `"high_tech_park"`, or `"industrial_cluster"`.
#' @param accuracy Optional location accuracy: `"site"` for records with a
#'   mapped boundary, `"locality"` for records placed by a nearby reference.
#' @param include Optional park identifiers or Vietnamese/English names.
#'
#' @return A data frame. See [industrial_parks_data] for the column contract
#'   and data provenance.
#'
#' @seealso [industrial_parks()], [industrial_park_coverage()]
#'
#' @examples
#' registry <- industrial_park_registry(province = "Dong Nai")
#' head(registry[c("id", "name_vi", "commune_name", "area_ha")])
#'
#' # Parks placed only by a nearby gate, bus stop or internal road.
#' nrow(industrial_park_registry(accuracy = "locality"))
#' @export
industrial_park_registry <- function(province = NULL, status = NULL,
                                     category = NULL, accuracy = NULL,
                                     include = NULL) {
  file <- system.file("extdata", "industrial_park_registry.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled industrial park data could not be found.", call. = FALSE)
  .filter_parks(readRDS(file), province, status, category, accuracy, include)
}

#' Report industrial-park mapping coverage
#'
#' Compares the bundled registry with the official count of established
#' industrial parks. The registry is a conservative snapshot: a park is recorded
#' only where a redistributable mapped location exists, so it is smaller than
#' the official register and unevenly complete across provinces. This function
#' makes that gap explicit rather than leaving it implied.
#'
#' @param scope `"province"` for mapped records per current province, or
#'   `"national"` to compare the registry against the official national totals.
#'
#' @return A data frame. For `scope = "province"`: `province_code`,
#'   `province_en`, `parks`, `with_boundary`, `locality_only`, and
#'   `mapped_area_ha`, with one row per current provincial unit including those
#'   holding no mapped park. For `scope = "national"`: one row per official
#'   metric with the official `value`, the comparable `mapped` figure where one
#'   exists, and the cited source.
#'
#' @seealso [industrial_park_registry()]
#'
#' @examples
#' head(industrial_park_coverage())
#' industrial_park_coverage("national")[1:3, c("metric", "value", "mapped")]
#' @export
industrial_park_coverage <- function(scope = c("province", "national")) {
  scope <- match.arg(scope)
  registry <- industrial_park_registry()
  if (identical(scope, "province")) {
    info <- .vn_info("provinces")
    counted <- table(factor(registry$province_code, levels = info$code))
    boundary <- table(factor(
      registry$province_code[registry$location_accuracy == "site"],
      levels = info$code))
    area <- tapply(registry$area_ha, factor(registry$province_code, levels = info$code),
                   sum, na.rm = TRUE)
    area[is.na(area)] <- 0
    out <- data.frame(
      province_code = info$code,
      province_en = info$name_en,
      parks = as.integer(counted),
      with_boundary = as.integer(boundary),
      locality_only = as.integer(counted) - as.integer(boundary),
      mapped_area_ha = round(as.numeric(area), 1),
      stringsAsFactors = FALSE
    )
    return(out[order(-out$parks, out$province_en), ])
  }

  file <- system.file("extdata", "industrial_park_baseline.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled industrial park data could not be found.", call. = FALSE)
  baseline <- readRDS(file)
  parks <- registry[registry$category %in% c("industrial_park",
                                             "export_processing_zone"), , drop = FALSE]
  mapped <- c(
    established_industrial_parks = nrow(parks),
    established_natural_area = round(sum(parks$area_ha, na.rm = TRUE)),
    under_construction_industrial_parks = sum(parks$status == "under_construction")
  )
  baseline$mapped <- unname(mapped[baseline$metric])
  baseline$coverage <- round(baseline$mapped / baseline$value, 3)
  baseline[c("metric", "value", "mapped", "coverage", "unit", "as_of", "scope",
             "source_name", "source_url")]
}

# Shared filtering for the registry and its spatial counterpart. `x` is any data
# frame carrying the registry columns, so the same argument contract holds
# whether or not geometry is attached.
.filter_parks <- function(x, province = NULL, status = NULL, category = NULL,
                          accuracy = NULL, include = NULL) {
  if (!is.null(province)) {
    current <- tryCatch(province_code(province), error = function(e) NULL)
    former <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
    if (is.null(current) && is.null(former)) {
      stop("Unknown province or municipality: ", paste(province, collapse = ", "),
           call. = FALSE)
    }
    keep <- rep(FALSE, nrow(x))
    if (!is.null(current)) keep <- keep | x$province_code %in% current
    if (!is.null(former)) keep <- keep | x$former_province_code %in% former
    x <- x[keep, , drop = FALSE]
  }
  if (!is.null(status)) {
    allowed <- c("operational", "under_construction",
                 "established_not_started", "unknown")
    bad <- setdiff(status, allowed)
    if (length(bad)) {
      stop("Unknown industrial park status: ", paste(bad, collapse = ", "), call. = FALSE)
    }
    x <- x[x$status %in% status, , drop = FALSE]
  }
  if (!is.null(category)) {
    allowed <- c("industrial_park", "export_processing_zone", "high_tech_park",
                 "industrial_cluster")
    bad <- setdiff(category, allowed)
    if (length(bad)) {
      stop("Unknown industrial park category: ", paste(bad, collapse = ", "), call. = FALSE)
    }
    x <- x[x$category %in% category, , drop = FALSE]
  }
  if (!is.null(accuracy)) {
    allowed <- c("site", "locality")
    bad <- setdiff(accuracy, allowed)
    if (length(bad)) {
      stop("Unknown location accuracy: ", paste(bad, collapse = ", "), call. = FALSE)
    }
    x <- x[x$location_accuracy %in% accuracy, , drop = FALSE]
  }
  if (!is.null(include)) {
    keys <- .vn_key(include)
    alias_hit <- vapply(strsplit(x$aliases, "\\|"), function(a) {
      any(.vn_key(a) %in% keys)
    }, logical(1))
    keep <- .vn_key(x$id) %in% keys | .vn_key(x$name_vi) %in% keys |
      .vn_key(x$name_en) %in% keys | .vn_key(x$park_key) %in% keys | alias_hit
    x <- x[keep, , drop = FALSE]
  }
  if (!nrow(x)) stop("No industrial parks matched the requested filters.", call. = FALSE)
  row.names(x) <- NULL
  x
}
