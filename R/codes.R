.vn_key <- function(x) {
  x <- stringi::stri_trans_general(as.character(x), "Latin-ASCII")
  x <- tolower(gsub("[^a-zA-Z0-9]", "", x))
  sub("^(tinh|thanhpho)", "", x)
}

.vn_info <- function(geography) {
  file <- system.file("extdata", paste0(geography, "_info.rds"), package = "vnmap")
  if (!nzchar(file)) stop("Bundled province metadata could not be found.", call. = FALSE)
  readRDS(file)
}

#' Look up Vietnamese provincial administrative codes
#'
#' Names may be written with or without Vietnamese diacritics. Current names,
#' English names, two-digit codes, and ISO 3166-2 codes are accepted.
#' @param x Character vector of names or codes.
#' @param geography Current `"provinces"` or historical `"provinces_63"`.
#' @return A character vector of two-digit administrative codes.
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
#' @param x Optional names or codes. When omitted, returns every unit.
#' @param geography Current `"provinces"` or historical `"provinces_63"`.
#' @return A data frame with codes and Vietnamese and English names.
#' @export
province_info <- function(x = NULL, geography = c("provinces", "provinces_63")) {
  geography <- match.arg(geography)
  info <- .vn_info(geography)
  info$aliases <- NULL
  if (is.null(x)) return(info)
  info[match(province_code(x, geography), info$code), , drop = FALSE]
}
