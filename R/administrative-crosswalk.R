.crosswalk_url <- paste0(
  "https://danhmuchanhchinh.nso.gov.vn/TAPTIN/",
  "BangChuyendoi%C4%90VHCmoi_cu_final.xlsx"
)

#' Download the NSO old/new administrative-unit workbook
#'
#' @param destfile Destination for the downloaded `.xlsx` file.
#' @param overwrite Whether to replace an existing file.
#' @return The normalized destination path, invisibly.
#' @details Download is explicit because `vnmap` has not established terms
#'   permitting redistribution of the NSO workbook or a substantial extracted
#'   table. The file remains under its source's terms and is not bundled.
#' @export
download_administrative_crosswalk <- function(
    destfile = file.path(getwd(), "nso-admin-crosswalk-new-old.xlsx"),
    overwrite = FALSE) {
  if (file.exists(destfile) && !isTRUE(overwrite)) {
    stop("Destination exists; set `overwrite = TRUE` to replace it.", call. = FALSE)
  }
  dir.create(dirname(destfile), recursive = TRUE, showWarnings = FALSE)
  status <- tryCatch(
    suppressWarnings(utils::download.file(.crosswalk_url, destfile,
                                           mode = "wb", quiet = FALSE)),
    error = function(e) e
  )
  if (inherits(status, "error") || !identical(status, 0L) ||
      !file.exists(destfile) || file.info(destfile)$size <= 0L) {
    if (file.exists(destfile)) unlink(destfile)
    detail <- if (inherits(status, "error")) conditionMessage(status) else paste0("status ", status)
    stop("Administrative crosswalk download failed (", detail, ").", call. = FALSE)
  }
  invisible(normalizePath(destfile, mustWork = TRUE))
}

.is_partial_transfer <- function(note) {
  normalized <- gsub("[[:space:]]+", " ", trimws(ifelse(is.na(note), "", note)))
  grepl("(^|[^[:alpha:]])(0*1|m\u1ed9t)[[:space:]]*ph\u1ea7n([^[:alpha:]]|$)",
        normalized, ignore.case = TRUE, perl = TRUE)
}

.validate_crosswalk_codes <- function(x) {
  if (!nrow(x)) stop("The workbook contains no administrative relationships.", call. = FALSE)
  for (field in c("current_code", "former_code")) {
    value <- x[[field]]
    if (anyNA(value) || any(!grepl("^[0-9]{1,5}$", value))) {
      stop("The workbook contains invalid ", field, " values.", call. = FALSE)
    }
  }
  province_codes <- lapply(c("current_province", "former_province"), function(field) {
    sub(".*\\(([0-9]{2})\\)$", "\\1", x[[field]])
  })
  bad_province <- vapply(province_codes, function(value) {
    anyNA(value) || any(!grepl("^[0-9]{2}$", value))
  }, logical(1))
  if (any(bad_province)) {
    stop("The workbook contains invalid or missing province codes.", call. = FALSE)
  }
  province_codes
}

.parse_administrative_crosswalk <- function(path) {
  if (!file.exists(path)) stop("Crosswalk workbook does not exist: ", path, call. = FALSE)
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required to parse the NSO workbook.", call. = FALSE)
  }
  raw <- readxl::read_excel(path, sheet = 2, skip = 2,
                            col_names = FALSE, col_types = "text")
  if (ncol(raw) < 8L) stop("The workbook does not have the expected eight columns.", call. = FALSE)
  x <- as.data.frame(raw[, seq_len(8)])
  names(x) <- c("current_province", "current_name", "current_code",
                "former_name", "former_code", "change_note",
                "former_district", "former_province")
  x <- x[!is.na(x$current_code) & !is.na(x$former_code), , drop = FALSE]
  province_codes <- .validate_crosswalk_codes(x)
  x$current_code <- sprintf("%05d", as.integer(x$current_code))
  x$former_code <- sprintf("%05d", as.integer(x$former_code))
  x$current_province_code <- province_codes[[1L]]
  x$former_province_code <- province_codes[[2L]]
  x$relation <- ifelse(.is_partial_transfer(x$change_note), "part", "whole")
  x$geography_vintage_from <- "before_2025-07-01"
  x$geography_vintage_to <- "2025-07-01_snapshot"
  x$source_url <- .crosswalk_url
  x$observed_on <- as.Date(file.info(path)$mtime)
  x <- x[c("former_code", "former_name", "former_district",
           "former_province_code", "former_province", "current_code",
           "current_name", "current_province_code", "current_province",
           "relation", "change_note", "geography_vintage_from",
           "geography_vintage_to", "source_url", "observed_on")]
  current_file <- system.file("extdata", "communes.rds", package = "vnmap")
  current_codes <- if (nzchar(current_file)) readRDS(current_file)$code else character()
  x$current_code_status <- ifelse(x$current_code %in% current_codes,
                                  "present_in_2026_snapshot",
                                  "not_present_in_2026_snapshot")
  attr(x, "crosswalk_only_codes") <- setdiff(unique(x$current_code), current_codes)
  attr(x, "current_snapshot_only_codes") <- setdiff(current_codes, unique(x$current_code))
  x
}

#' Parse and query the 2025 administrative-unit crosswalk
#'
#' @param path Path to the official NSO `.xlsx` workbook, normally obtained
#'   with [download_administrative_crosswalk()].
#' @param current Optional current commune names or five-digit codes.
#' @param former Optional former commune names or five-digit codes.
#' @param province Optional current or former provincial identifier accepted by
#'   [province_code()]. Rows matching either geography are retained.
#' @return A data frame. The `relation` column is `"whole"` or `"part"`.
#'   Reconciliation with the bundled 2026 snapshot is reported in
#'   `current_code_status` and in the `crosswalk_only_codes` and
#'   `current_snapshot_only_codes` attributes.
#' @details This table is inherently many-to-many: a former unit may be split
#'   among current units, and a current unit may combine several former units.
#'   It is a membership crosswalk, not an allocation-weight table. The source
#'   publishes no population or area shares, so none are inferred.
#'
#'   The workbook describes the July 2025 transition while bundled current
#'   boundaries are a 25 July 2026 observed snapshot. Status fields expose
#'   differences rather than silently coercing codes between vintages. No
#'   per-code legal effective date is assigned.
#' @examples
#' \dontrun{
#' path <- download_administrative_crosswalk(tempfile(fileext = ".xlsx"))
#' administrative_crosswalk(path, current = "00004")
#' }
#' @export
administrative_crosswalk <- function(path, current = NULL, former = NULL,
                                     province = NULL) {
  x <- .parse_administrative_crosswalk(path)
  .filter_administrative_crosswalk(x, current, former, province)
}

.filter_administrative_crosswalk <- function(x, current = NULL, former = NULL,
                                             province = NULL) {
  keep <- rep(TRUE, nrow(x))
  if (!is.null(current)) {
    key <- .vn_key(current)
    keep <- keep & (.vn_key(x$current_code) %in% key | .vn_key(x$current_name) %in% key)
  }
  if (!is.null(former)) {
    key <- .vn_key(former)
    keep <- keep & (.vn_key(x$former_code) %in% key | .vn_key(x$former_name) %in% key)
  }
  if (!is.null(province)) {
    new <- tryCatch(province_code(province, "provinces"), error = function(e) NULL)
    old <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
    if (is.null(new) && is.null(old)) {
      stop("Unknown current or historical province: ",
           paste(province, collapse = ", "), call. = FALSE)
    }
    keep <- keep & (x$current_province_code %in% new | x$former_province_code %in% old)
  }
  attrs <- attributes(x)[c("crosswalk_only_codes", "current_snapshot_only_codes")]
  out <- x[keep, , drop = FALSE]
  if (!nrow(out)) stop("No administrative crosswalk rows matched the filters.", call. = FALSE)
  rownames(out) <- NULL
  for (nm in names(attrs)) attr(out, nm) <- attrs[[nm]]
  out
}
