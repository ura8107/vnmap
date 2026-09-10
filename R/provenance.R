.vn_manifest <- function() {
  cached <- .vn_cache[["manifest"]]
  if (!is.null(cached)) return(cached)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to read the data manifest. ",
         "Install it with install.packages(\"jsonlite\").", call. = FALSE)
  }
  file <- system.file("extdata", "manifest.json", package = "vnmap")
  if (!nzchar(file)) stop("The bundled data manifest could not be found.", call. = FALSE)
  out <- jsonlite::read_json(file)
  .vn_cache[["manifest"]] <- out
  out
}

#' Describe where the bundled data came from
#'
#' Returns the recorded provenance of every dataset shipped with `vnmap`: its
#' source and licence, the vintage of the geometry, how far it has been
#' generalized, the administrative decision it follows, and the script that
#' built it.
#'
#' @param layer Optional layer names, as returned in the `layer` column. When
#'   omitted, every dataset is described.
#'
#' @return A data frame with one row per dataset:
#'   \describe{
#'     \item{layer}{Name used by [vn_map()] or by the exported dataset.}
#'     \item{file}{Path within the package sources.}
#'     \item{storage}{`"extdata"` for datasets that ship as files, whose
#'       checksum can be verified after installation; `"lazydata"` for those
#'       folded into the lazy-load database by `LazyData`, whose `md5`
#'       describes the repository file only.}
#'     \item{title, description}{What the dataset holds.}
#'     \item{n_features}{Rows in the layer as built.}
#'     \item{crs}{Coordinate reference system as stored, `NA` for tables
#'       without geometry. [vn_map()] transforms on read, so this is not
#'       necessarily the CRS you receive.}
#'     \item{geometry_vintage}{When the boundaries or features were observed.}
#'     \item{geometry_accuracy}{How far the geometry has been generalized, and
#'       what it may not be used for.}
#'     \item{administrative_basis}{The decision or geography the units follow.}
#'     \item{source_name, source_url, source_ref, source_license,
#'       source_upstream}{Where the data came from and on what terms.}
#'     \item{build_script}{The script under `data-raw/` that regenerates it.}
#'     \item{md5}{Checksum of the shipped file.}
#'   }
#'
#' @details Geometry in this package is derived from more than one upstream
#'   source with different vintages, so the vintage belongs to the layer rather
#'   than to the package. The current provincial and commune layers share a
#'   2026 observed snapshot; the pre-reform provincial layer is derived from
#'   geoBoundaries geometry whose represented year is 2008. None of it is a
#'   surveying, navigation or legal-boundary product.
#'
#'   `md5` and `n_features` are checked against the shipped data by the
#'   package's own tests, so a rebuilt layer whose manifest was not updated
#'   fails rather than silently describing the previous build.
#'
#' @seealso [vn_map()], [industrial_parks()], [infrastructure()]
#'
#' @examples
#' vn_provenance()[, c("layer", "n_features", "geometry_vintage")]
#' vn_provenance("communes")$source_license
#' @export
vn_provenance <- function(layer = NULL) {
  layers <- .vn_manifest()$layers
  chr <- function(v) if (is.null(v)) NA_character_ else as.character(v)
  out <- do.call(rbind, lapply(layers, function(e) {
    data.frame(
      layer = chr(e$layer), file = chr(e$file), storage = chr(e$storage),
      title = chr(e$title),
      description = chr(e$description),
      n_features = if (is.null(e$n_features)) NA_integer_ else as.integer(e$n_features),
      crs = chr(e$crs), geometry_vintage = chr(e$geometry_vintage),
      geometry_accuracy = chr(e$geometry_accuracy),
      administrative_basis = chr(e$administrative_basis),
      source_name = chr(e$source$name), source_url = chr(e$source$url),
      source_ref = chr(e$source$ref), source_license = chr(e$source$license),
      source_upstream = chr(e$source$upstream),
      build_script = chr(e$build_script), md5 = chr(e$md5),
      stringsAsFactors = FALSE
    )
  }))
  row.names(out) <- NULL
  if (is.null(layer)) return(out)
  idx <- match(as.character(layer), out$layer)
  if (anyNA(idx)) {
    stop("Unknown layer: ", paste(unique(as.character(layer)[is.na(idx)]), collapse = ", "),
         ". Available: ", paste(out$layer, collapse = ", "), call. = FALSE)
  }
  out[idx, , drop = FALSE]
}
