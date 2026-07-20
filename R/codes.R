.vn_key <- function(x) {
  x <- stringi::stri_trans_general(as.character(x), "Latin-ASCII")
  x <- tolower(gsub("[^a-zA-Z0-9]", "", x))
  sub("^(tinh|thanhpho)", "", x)
}

.vn_info <- function(geography) {
  file <- system.file("extdata", paste0(geography, "_info.rds"), package = "vnmap")
  if (!nzchar(file)) stop("Bundled province metadata could not be found.", call. = FALSE)
  info <- readRDS(file)
  # The lookup table is used without 'sf'; drop any geometry an older bundled
  # artifact may still carry so a plain data frame is always returned.
  if ("geometry" %in% names(info)) {
    info[["geometry"]] <- NULL
    attr(info, "sf_column") <- NULL
    attr(info, "agr") <- NULL
    class(info) <- "data.frame"
  }
  info
}

#' Look up Vietnamese provincial administrative codes
#'
#' Names may be written with or without Vietnamese diacritics. Current names,
#' English names, two-digit codes, and ISO 3166-2 codes are accepted.
#'
#' @param x Character vector of names or codes.
#' @param geography Either `"provinces"` for the current 34-unit geography or
#'   `"provinces_63"` for the historical 63-unit geography.
#'
#' @return A character vector of two-digit administrative codes.
#'
#' @details Input is matched case-insensitively after punctuation, whitespace,
#'   administrative prefixes, and Vietnamese diacritics are normalized.
#'   Common aliases such as `"Hanoi"`, `"Danang"`, `"HCMC"`, and `"Saigon"`
#'   are supported. An error lists any values that cannot be matched.
#'
#'   Codes are geography-specific. For example, a former province that was
#'   merged in 2025 can be found only with `geography = "provinces_63"`.
#'
#' @seealso [province_info()], [vn_map()]
#'
#' @examples
#' province_code(c("Da Nang", "Danang", "48"))
#' province_code(c("HCMC", "Saigon"))
#' province_code("Bac Giang", geography = "provinces_63")
#' @export
province_code <- function(x, geography = c("provinces", "provinces_63")) {
  geography <- match.arg(geography)
  info <- .vn_info(geography)
  aliases <- unlist(strsplit(info$aliases, "\\|", fixed = FALSE))
  rows <- rep(seq_len(nrow(info)), lengths(strsplit(info$aliases, "\\|", fixed = FALSE)))
  iso_ok <- !is.na(info$iso) & nzchar(info$iso)
  keys <- c(.vn_key(aliases), .vn_key(info$code), .vn_key(info$iso[iso_ok]))
  vals <- c(info$code[rows], info$code, info$code[iso_ok])
  answer <- unname(vals[match(.vn_key(x), keys)])
  if (anyNA(answer)) {
    bad <- unique(as.character(x)[is.na(answer)])
    stop("Unknown province or municipality: ", paste(bad, collapse = ", "), call. = FALSE)
  }
  answer
}

#' Retrieve metadata for Vietnamese provincial units
#'
#' Returns the lookup table used by `vnmap` to join statistical data to map
#' geometry. Supplying `x` filters and orders the result to match the input.
#'
#' @param x Optional names or codes. When omitted, returns every unit.
#' @param geography Either `"provinces"` for the current 34-unit geography or
#'   `"provinces_63"` for the historical 63-unit geography.
#'
#' @return A data frame containing `code`, `iso`, `name_vi`, `name_en`, `type`,
#'   `region_code`, `region_vi`, and `region_en`. The `type` column
#'   distinguishes provinces from centrally governed municipalities, and the
#'   `region_*` columns give the socio-economic region (see
#'   [province_region()]).
#'
#' @details With no `x`, rows are returned in ascending official code order.
#'   With `x`, names and aliases are normalized by [province_code()] and the
#'   returned rows follow the order of `x`.
#'
#' @seealso [province_code()], [province_region()], [vn_map()]
#'
#' @examples
#' head(province_info())
#' province_info(c("01", "HCMC"))
#' province_info("Bac Giang", geography = "provinces_63")
#' @export
province_info <- function(x = NULL, geography = c("provinces", "provinces_63")) {
  geography <- match.arg(geography)
  info <- .vn_info(geography)
  info$aliases <- NULL
  reg <- .vn_regions(geography)
  idx <- match(info$code, reg$code)
  info$region_code <- reg$region_code[idx]
  info$region_vi <- reg$region_vi[idx]
  info$region_en <- reg$region_en[idx]
  if (is.null(x)) return(info)
  info[match(province_code(x, geography), info$code), , drop = FALSE]
}
