# Lookup tables --------------------------------------------------------------

.vn_cache <- new.env(parent = emptyenv())

# An index over one set of units: the normalized keys for every name and alias
# that resolves to each row, plus the codes that resolve directly. Built from a
# plain data frame so that on-demand layers can be matched the same way as the
# bundled ones.
.vn_index <- function(tab, alias_of, code_text = tab$code,
                      code_row = seq_len(nrow(tab))) {
  rows <- rep(seq_len(nrow(tab)), lengths(alias_of))
  alias <- data.frame(row = rows, text = unlist(alias_of, use.names = FALSE),
                      stringsAsFactors = FALSE)
  alias <- alias[!is.na(alias$text) & nzchar(alias$text), , drop = FALSE]
  list(
    tab = tab, alias = alias,
    code_key = .vn_key(code_text), code_row = code_row,
    keys = list(exact = .vn_norm(alias$text), ascii = .vn_key(alias$text),
                loose = .vn_key_loose(alias$text))
  )
}

# Strip the geometry column without requiring 'sf', so that name lookups keep
# working when only the lookups are needed.
.vn_drop_geometry <- function(x) {
  geom <- attr(x, "sf_column")
  if (is.null(geom)) geom <- "geometry"
  x[[geom]] <- NULL
  attr(x, "sf_column") <- NULL
  attr(x, "agr") <- NULL
  class(x) <- "data.frame"
  x
}

# Reshape any layer carrying name columns into the frame `.vn_index()` wants.
.vn_unit_table <- function(x) {
  parent_code <- if ("province_code" %in% names(x)) x$province_code else NA_character_
  parent_name <- if ("province_en" %in% names(x)) x$province_en else NA_character_
  data.frame(
    code = x$code,
    name_vi = if ("name_vi" %in% names(x)) x$name_vi else x$code,
    name_en = if ("name_en" %in% names(x)) x$name_en else NA_character_,
    parent_code = parent_code, parent_name = parent_name,
    stringsAsFactors = FALSE
  )
}

# One row per unit, plus the alias strings that resolve to it.
.vn_lookup <- function(geography) {
  cached <- .vn_cache[[geography]]
  if (!is.null(cached)) return(cached)

  if (geography == "communes") {
    file <- system.file("extdata", "communes.rds", package = "vnmap")
    if (!nzchar(file)) stop("Bundled commune data could not be found.", call. = FALSE)
    tab <- .vn_unit_table(.vn_drop_geometry(readRDS(file)))
    out <- .vn_index(tab, Map(function(vi, en) unique(c(vi, en)), tab$name_vi, tab$name_en))
  } else {
    info <- .vn_info(geography)
    tab <- .vn_unit_table(info)
    ok <- !is.na(info$iso) & nzchar(info$iso)
    out <- .vn_index(tab, strsplit(info$aliases, "|", fixed = TRUE),
                     code_text = c(info$code, info$iso[ok]),
                     code_row = c(seq_len(nrow(info)), which(ok)))
  }
  .vn_cache[[geography]] <- out
  out
}

# The provincial geography that a lower-level layer's parent codes refer to.
.vn_parent_geography <- function(geography) {
  if (geography == "communes") "provinces" else NA_character_
}

# Matching -------------------------------------------------------------------

.vn_stage_key <- function(x, stage) {
  switch(stage, exact = .vn_norm(x), ascii = .vn_key(x), loose = .vn_key_loose(x))
}

# Resolve a parent hint to provincial codes, returning NULL when it is not a
# real parent name. Used both for the `parent` argument and for the trailing
# part of "Tan Phu, Dong Nai".
.vn_parent_codes <- function(hint, parent_geography) {
  if (is.na(parent_geography) || is.null(hint)) return(NULL)
  hint <- hint[!is.na(hint) & nzchar(hint)]
  if (!length(hint)) return(NULL)
  got <- .vn_match_index(hint, .vn_lookup(parent_geography), parent_codes = NULL,
                         max_distance = 0L, parent_geography = NA_character_)
  codes <- got$code[!is.na(got$code)]
  if (!length(codes)) NULL else codes
}

# Split "Tan Phu, Dong Nai" or "Tan Phu (Dong Nai)" into name and parent hint,
# but only when the trailing part really names a parent. Without that guard a
# string such as "Xuan Loc, khu 3" would be torn apart.
.vn_split_parent <- function(x, parent_geography) {
  m <- regmatches(x, regexec("^\\s*(.*\\S)\\s*[,(]\\s*([^,()]+?)\\)?\\s*$", x))
  name <- x
  hint <- rep(NA_character_, length(x))
  for (i in seq_along(m)) {
    if (length(m[[i]]) != 3L) next
    if (is.null(.vn_parent_codes(m[[i]][3L], parent_geography))) next
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
.vn_match_index <- function(x, lk, parent_codes, max_distance, parent_geography,
                            hint = NULL) {
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

  keys_in <- lapply(c("exact", "ascii", "loose"), function(s) .vn_stage_key(x, s))
  names(keys_in) <- c("exact", "ascii", "loose")
  code_in <- .vn_key(x)

  for (i in seq_along(x)) {
    if (is.na(x[i]) || !nzchar(trimws(x[i]))) next

    # A per-input hint beats the vector-wide `parent` argument.
    limit <- parent_codes
    if (!is.null(hint) && !is.na(hint[i])) {
      limit <- .vn_parent_codes(hint[i], parent_geography)
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
    for (stage in c("exact", "ascii", "loose")) {
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
#'       `"loose"` (only after removing an administrative prefix written
#'       without diacritics), `"ambiguous"`, `"fuzzy"`, or `"none"`.}
#'     \item{matched_on}{The name or alias that produced the match.}
#'     \item{distance}{Edit distance, for `"fuzzy"` rows.}
#'     \item{n_candidates, candidates, candidate_names}{The units considered,
#'       as counts and as `|`-separated codes and labels.}
#'   }
#'
#' @details Normalization is attempted in order, stopping at the first step
#'   that finds anything: administrative codes, then names compared with their
#'   tone marks intact, then with diacritics removed, then with an
#'   undiacriticked administrative prefix removed. Recording the
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

  pg <- .vn_parent_geography(geography)
  parent_codes <- NULL
  if (!is.null(parent)) {
    if (is.na(pg)) {
      stop("`parent` is only available for lower-level geography.", call. = FALSE)
    }
    parent_codes <- province_code(parent, pg)
  }
  split <- .vn_split_parent(x, pg)
  out <- .vn_match_index(split$name, .vn_lookup(geography), parent_codes,
                         as.integer(max_distance), pg, hint = split$hint)
  out$input <- x
  out
}

# Errors ---------------------------------------------------------------------

# Build the error for names that did not resolve. Suggestions come from
# `vn_match()`, which offers them without ever applying them, so a typo
# produces something a reader can act on rather than a bare rejection.
# `lk` is the index the names were matched against, so that candidate codes are
# read back from the same set of units rather than from a bundled layer that
# may not be the one being filtered.
.vn_unmatched_message <- function(got, geography, lk = NULL) {
  lower <- !geography %in% c("provinces", "provinces_63")
  noun <- switch(geography, districts_63 = "district",
                 provinces = , provinces_63 = "province or municipality", "commune")
  bad <- got[is.na(got$code), , drop = FALSE]
  bad <- bad[!duplicated(bad$input), , drop = FALSE]
  lines <- paste0("Unknown ", noun, ": ",
                  paste0("\"", bad$input, "\"", collapse = ", "), ".")

  for (i in seq_len(nrow(bad))) {
    if (bad$n_candidates[i] == 0L) next
    names_i <- strsplit(bad$candidate_names[i], "|", fixed = TRUE)[[1L]]
    codes_i <- strsplit(bad$candidates[i], "|", fixed = TRUE)[[1L]]
    shown <- paste0("\"", utils::head(names_i, 4L), "\" (",
                    utils::head(codes_i, 4L), ")", collapse = ", ")
    more <- if (length(names_i) > 4L) paste0(", and ", length(names_i) - 4L, " more") else ""
    ambiguous <- bad$match_type[i] == "ambiguous"
    lead <- if (ambiguous) "matches several units: " else "did you mean "
    end <- if (ambiguous) "" else "?"
    lines <- c(lines, paste0("  \"", bad$input[i], "\" - ", lead, shown, more, end))
  }

  if (lower) {
    amb <- bad[bad$match_type == "ambiguous", , drop = FALSE]
    if (nrow(amb)) {
      # A parent only helps when the candidates sit in different provinces.
      # Candidates sharing one province differ by their tone marks alone, and
      # no province can tell them apart.
      spread <- vapply(strsplit(amb$candidates, "|", fixed = TRUE), function(codes) {
        parents <- lk$tab$parent_code[match(codes, lk$tab$code)]
        length(unique(parents)) > 1L
      }, logical(1))
      if (any(spread)) {
        lines <- c(lines, paste0("  Commune names repeat across provinces. Supply ",
                                 "`province`, or write the value as \"Tan Phu, Dong Nai\"."))
      }
      if (any(!spread)) {
        lines <- c(lines, paste0("  Candidates within one province differ only by ",
                                 "their diacritics; write the name with tone marks."))
      }
    }
  } else {
    other <- .vn_other_geography(bad$input, geography)
    if (!is.null(other)) lines <- c(lines, other)
  }

  c(paste(lines, collapse = "\n"),
    "\nUse vn_match() to inspect all matches without raising an error.")
}

# The 2025 reform replaced 63 provincial units with 34, so a table prepared
# under one geography and plotted against the other fails wholesale rather than
# in one place. When most of the unmatched names belong to the other geography,
# say so: that is far more often the real mistake than a set of typos.
.vn_other_geography <- function(inputs, geography) {
  other <- if (geography == "provinces") "provinces_63" else "provinces"
  hit <- sum(!is.na(vn_match(inputs, other, max_distance = 0L)$code))
  if (hit < 2L || hit < length(inputs) * 0.6) return(NULL)
  label <- if (other == "provinces_63") "pre-July-2025" else "current 34-unit"
  c(paste0("  ", hit, " of ", length(inputs), " unmatched names match the ",
           label, " geography."),
    paste0("  Did you mean geography = \"", other, "\"?"))
}

#' Look up Vietnamese commune-level administrative codes
#'
#' Commune names are not unique across the country: the bundled layer holds
#' 3,321 units, 314 of whose names are used by more than one province. A name
#' matching several units is therefore an error rather than an arbitrary
#' choice, and `province` says which one is meant.
#'
#' @param x Character vector of commune names or codes. A name may carry its
#'   province, written as `"Tan Phu, Dong Nai"` or `"Tan Phu (Dong Nai)"`.
#' @param province Optional provincial identifiers accepted by
#'   [province_code()], used to resolve names shared by several communes.
#'
#' @return A character vector of commune codes.
#'
#' @details Names may be written with or without Vietnamese diacritics, but
#'   the two are not equivalent evidence. Ten pairs of communes inside a single
#'   province differ only by their tone marks -- `"My Tho"` and `"My Tho"` in
#'   Dong Thap among them -- so a name written without diacritics can be
#'   irreducibly ambiguous even when `province` is supplied. Such a value is
#'   reported rather than resolved.
#'
#'   An error lists every candidate for an ambiguous name, so the province that
#'   disambiguates it can be read off the message.
#'
#' @seealso [province_code()], [vn_match()], [vn_map()]
#'
#' @examples
#' commune_code("Tan Phu, Dong Nai")
#' commune_code("Tan Phu", province = "Dong Nai")
#' commune_code("Tinh Bien")
#'
#' # Two communes are called Thanh Phong; only the tone marks separate them.
#' vn_match("Thanh Phong", "communes")$candidate_names
#' commune_code("Thanh Phong", province = "Thanh Hoa")
#' @export
commune_code <- function(x, province = NULL) {
  got <- vn_match(x, "communes", parent = province)
  if (anyNA(got$code)) {
    stop(.vn_unmatched_message(got, "communes", .vn_lookup("communes")), call. = FALSE)
  }
  got$code
}
