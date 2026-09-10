# Lookup tables --------------------------------------------------------------

.vn_cache <- new.env(parent = emptyenv())

# One row per unit, plus the alias strings that resolve to it. Built without
# 'sf' so that name lookups keep working when only the lookups are needed.
.vn_lookup <- function(geography) {
  cached <- .vn_cache[[geography]]
  if (!is.null(cached)) return(cached)

  if (geography == "communes") {
    file <- system.file("extdata", "communes.rds", package = "vnmap")
    if (!nzchar(file)) stop("Bundled commune data could not be found.", call. = FALSE)
    map <- readRDS(file)
    geom <- attr(map, "sf_column")
    if (is.null(geom)) geom <- "geometry"
    map[[geom]] <- NULL
    attr(map, "sf_column") <- NULL
    attr(map, "agr") <- NULL
    class(map) <- "data.frame"
    tab <- data.frame(
      code = map$code, name_vi = map$name_vi, name_en = map$name_en,
      parent_code = map$province_code, parent_name = map$province_en,
      stringsAsFactors = FALSE
    )
    alias_of <- Map(function(vi, en) unique(c(vi, en)), tab$name_vi, tab$name_en)
    iso <- NULL
  } else {
    info <- .vn_info(geography)
    tab <- data.frame(
      code = info$code, name_vi = info$name_vi, name_en = info$name_en,
      parent_code = NA_character_, parent_name = NA_character_,
      stringsAsFactors = FALSE
    )
    alias_of <- strsplit(info$aliases, "|", fixed = TRUE)
    iso <- info$iso
  }

  rows <- rep(seq_len(nrow(tab)), lengths(alias_of))
  alias <- data.frame(row = rows, text = unlist(alias_of, use.names = FALSE),
                      stringsAsFactors = FALSE)

  # Codes and ISO codes resolve directly and are held apart from the names.
  code_text <- tab$code
  code_row <- seq_len(nrow(tab))
  if (!is.null(iso)) {
    ok <- !is.na(iso) & nzchar(iso)
    code_text <- c(code_text, iso[ok])
    code_row <- c(code_row, which(ok))
  }

  out <- list(
    tab = tab, alias = alias,
    code_key = .vn_key(code_text), code_row = code_row,
    keys = list(
      exact = .vn_norm(alias$text), ascii = .vn_key(alias$text),
      token = .vn_tokens(alias$text), loose = .vn_key_loose(alias$text)
    )
  )
  .vn_cache[[geography]] <- out
  out
}

# The provincial geography that a lower-level layer's parent codes refer to.
.vn_parent_geography <- function(geography) {
  if (geography == "communes") "provinces" else NA_character_
}

# Matching -------------------------------------------------------------------

.vn_stage_key <- function(x, stage) {
  switch(stage, exact = .vn_norm(x), ascii = .vn_key(x),
         token = .vn_tokens(x), loose = .vn_key_loose(x))
}

# Resolve a parent hint to provincial codes, returning NULL when it is not a
# real parent name. Used both for the `parent` argument and for the trailing
# part of "Tan Phu, Dong Nai".
.vn_parent_codes <- function(hint, geography) {
  pg <- .vn_parent_geography(geography)
  if (is.na(pg) || is.null(hint)) return(NULL)
  hint <- hint[!is.na(hint) & nzchar(hint)]
  if (!length(hint)) return(NULL)
  got <- .vn_match_one(hint, pg, parent_codes = NULL, max_distance = 0L)
  codes <- got$code[!is.na(got$code)]
  if (!length(codes)) NULL else codes
}

# Split "Tan Phu, Dong Nai" or "Tan Phu (Dong Nai)" into name and parent hint,
# but only when the trailing part really names a parent. Without that guard a
# string such as "Xuan Loc, khu 3" would be torn apart.
.vn_split_parent <- function(x, geography) {
  m <- regmatches(x, regexec("^\\s*(.*\\S)\\s*[,(]\\s*([^,()]+?)\\)?\\s*$", x))
  name <- x
  hint <- rep(NA_character_, length(x))
  for (i in seq_along(m)) {
    if (length(m[[i]]) != 3L) next
    if (is.null(.vn_parent_codes(m[[i]][3L], geography))) next
    name[i] <- m[[i]][2L]
    hint[i] <- m[[i]][3L]
  }
  list(name = name, hint = hint)
}

.vn_empty_result <- function(n) {
  data.frame(
    input = rep(NA_character_, n), code = rep(NA_character_, n),
    name_vi = rep(NA_character_, n), name_en = rep(NA_character_, n),
    parent_code = rep(NA_character_, n), match_type = rep("none", n),
    matched_on = rep(NA_character_, n), distance = rep(NA_integer_, n),
    n_candidates = rep(0L, n), candidates = rep(NA_character_, n),
    candidate_names = rep(NA_character_, n), stringsAsFactors = FALSE
  )
}

# Core matcher. `parent_codes` is already resolved; `hint` may carry a per-input
# parent taken from the "name, parent" form.
.vn_match_one <- function(x, geography, parent_codes, max_distance, hint = NULL) {
  lk <- .vn_lookup(geography)
  tab <- lk$tab
  out <- .vn_empty_result(length(x))
  out$input <- as.character(x)

  label <- function(rows) {
    nm <- tab$name_vi[rows]
    ifelse(is.na(tab$parent_name[rows]), nm,
           paste0(nm, " (", tab$parent_name[rows], ")"))
  }
  record <- function(i, rows, type, on = NA_character_, dist = NA_integer_) {
    out$n_candidates[i] <<- length(rows)
    out$candidates[i] <<- paste(tab$code[rows], collapse = "|")
    out$candidate_names[i] <<- paste(label(rows), collapse = "|")
    out$match_type[i] <<- type
    out$distance[i] <<- dist
    if (length(rows) == 1L && type != "fuzzy") {
      out$code[i] <<- tab$code[rows]
      out$name_vi[i] <<- tab$name_vi[rows]
      out$name_en[i] <<- tab$name_en[rows]
      out$parent_code[i] <<- tab$parent_code[rows]
      out$matched_on[i] <<- on
    }
  }

  keys_in <- lapply(c("exact", "ascii", "token", "loose"),
                    function(s) .vn_stage_key(x, s))
  names(keys_in) <- c("exact", "ascii", "token", "loose")
  code_in <- .vn_key(x)

  for (i in seq_along(x)) {
    if (is.na(x[i]) || !nzchar(trimws(x[i]))) next

    # A per-input hint beats the vector-wide `parent` argument.
    limit <- parent_codes
    if (!is.null(hint) && !is.na(hint[i])) {
      limit <- .vn_parent_codes(hint[i], geography)
    }
    narrow <- function(rows) {
      if (is.null(limit) || !length(rows)) return(rows)
      rows[tab$parent_code[rows] %in% limit]
    }

    j <- which(lk$code_key == code_in[i])
    if (length(j)) {
      record(i, unique(lk$code_row[j]), "code", on = out$input[i])
      next
    }

    done <- FALSE
    for (stage in c("exact", "ascii", "token", "loose")) {
      j <- which(lk$keys[[stage]] == keys_in[[stage]][i])
      if (!length(j)) next
      found <- unique(lk$alias$row[j])
      rows <- narrow(found)
      if (length(rows) == 1L) {
        on <- lk$alias$text[j][match(rows, lk$alias$row[j])]
        record(i, rows, stage, on = on[1L])
      } else if (length(rows) > 1L) {
        record(i, rows, "ambiguous")
      } else {
        # The name exists, but not inside the requested parent. Report the
        # units it does name, so the caller can see where it actually is.
        record(i, found, "none")
      }
      done <- TRUE
      break
    }
    if (done) next

    # Nothing matched. Offer candidates, but never resolve on them.
    if (max_distance > 0L && nchar(keys_in$ascii[i]) >= 4L) {
      uniq <- unique(lk$keys$ascii)
      d <- as.integer(utils::adist(keys_in$ascii[i], uniq))
      near <- which(d <= max_distance)
      if (length(near)) {
        best <- order(d[near])
        near <- near[best]
        rows <- unique(lk$alias$row[lk$keys$ascii %in% uniq[near]])
        rows <- narrow(rows)
        record(i, utils::head(rows, 5L), "fuzzy", dist = min(d[near]))
      }
    }
  }
  out
}

#' Match names against Vietnamese administrative units without failing
#'
#' Reports how each supplied name resolves, including the ones that do not.
#' Unlike [province_code()], which stops at the first unmatched value, this
#' returns one row per input describing what was found, which normalization
#' step found it, and which units were considered.
#'
#' @param x Character vector of names, aliases, or codes.
#' @param geography One of `"provinces"` (the 34 units effective from July
#'   2025), `"provinces_63"` (the preceding units), or `"communes"` (current
#'   commune-level units).
#' @param parent Optional provincial identifiers used to narrow commune
#'   candidates. Accepts anything [province_code()] accepts.
#' @param max_distance Largest edit distance at which unmatched names are
#'   offered a suggestion. Suggestions are reported, never applied; use `0` to
#'   switch them off.
#'
#' @return A data frame with one row per element of `x`:
#'   \describe{
#'     \item{input}{The value supplied.}
#'     \item{code}{The resolved code, or `NA` when nothing was resolved.}
#'     \item{name_vi, name_en, parent_code}{Populated on resolution only.}
#'     \item{match_type}{How the value resolved: `"code"`, `"exact"` (with
#'       diacritics intact), `"ascii"` (only after dropping diacritics),
#'       `"token"` (only after sorting words), `"loose"` (only after removing
#'       an administrative prefix written without diacritics), `"ambiguous"`,
#'       `"fuzzy"`, or `"none"`.}
#'     \item{matched_on}{The name or alias that produced the match.}
#'     \item{distance}{Edit distance, for `"fuzzy"` rows.}
#'     \item{n_candidates, candidates, candidate_names}{The units considered,
#'       as counts and as `|`-separated codes and labels.}
#'   }
#'
#' @details Normalization is attempted in order, stopping at the first step
#'   that finds anything: administrative codes, then names compared with their
#'   tone marks intact, then with diacritics removed, then with words sorted,
#'   then with an undiacriticked administrative prefix removed. Recording the
#'   step matters because dropping tone marks loses real distinctions: ten
#'   pairs of communes inside a single province differ only by their
#'   diacritics, so a `"exact"` match is stronger evidence than an `"ascii"`
#'   one.
#'
#'   Commune names repeat across the country, so a name matching several units
#'   is reported as `"ambiguous"` with `code` left `NA` rather than resolved
#'   arbitrarily. Supply `parent`, or write the value as `"Tan Phu, Dong Nai"`
#'   or `"Tan Phu (Dong Nai)"`; the trailing part is treated as a parent only
#'   when it names a real province.
#'
#'   `"fuzzy"` rows never resolve. Edit distance is used to suggest candidates
#'   for a human to confirm, so that a typo produces a usable message rather
#'   than a silent substitution.
#'
#' @seealso [province_code()], [commune_code()], [province_info()]
#'
#' @examples
#' vn_match(c("Ha Noi", "Hanoii", "48"))
#'
#' # Commune names repeat; a parent resolves them.
#' vn_match("Tan Phu", geography = "communes")[, c("input", "code", "match_type")]
#' vn_match("Tan Phu, Dong Nai", geography = "communes")$code
#' @export
vn_match <- function(x, geography = c("provinces", "provinces_63", "communes"),
                     parent = NULL, max_distance = 1L) {
  geography <- match.arg(geography)
  if (!is.numeric(max_distance) || length(max_distance) != 1L || is.na(max_distance) ||
      max_distance < 0) {
    stop("`max_distance` must be a single non-negative number.", call. = FALSE)
  }
  x <- as.character(x)
  if (!length(x)) return(.vn_empty_result(0L))

  parent_codes <- NULL
  if (!is.null(parent)) {
    if (is.na(.vn_parent_geography(geography))) {
      stop("`parent` is only available for lower-level geography.", call. = FALSE)
    }
    parent_codes <- province_code(parent, .vn_parent_geography(geography))
  }
  split <- .vn_split_parent(x, geography)
  out <- .vn_match_one(split$name, geography, parent_codes,
                       as.integer(max_distance), hint = split$hint)
  out$input <- x
  out
}
