# Name normalization ---------------------------------------------------------
#
# Matching Vietnamese unit names needs more than one key. Provincial names are
# distinct enough that an ASCII fold suffices, but the bundled commune layer
# holds 3,321 units, and ten pairs inside a single province differ only by
# their diacritics: "My Tho" against "My Tho", "Tan Thanh" against
# "Tan Thanh", "Ba To" against "Ba To". Folding those together destroys a
# distinction no parent hint can recover, so the tone-preserving key is tried
# first and the ASCII key only afterwards.

# Administrative words a caller may write in front of a unit name, longest
# first. They are held with their tone marks on purpose. The word for province
# is "tinh" with a hook above; the first syllable of Tinh Bien, Tinh Khe and
# Tinh Gia carries a dot below, and of Tinh Tuc a tilde. Likewise the word for
# city is "thanh" with a grave, while Thanh Phong and Thanh Phong carry none
# and a dot below. Requiring the tone to agree is what keeps those six real
# communes from being truncated to their second syllable.
.vn_prefix_words <- c(
  "thành phố",   # thanh pho, city
  "thị trấn",    # thi tran, township
  "thị xã",      # thi xa, town
  "huyện",            # huyen, rural district
  "phường",      # phuong, ward
  "tỉnh",             # tinh, province
  "quận",             # quan, urban district
  "xã",               # xa, commune
  "tp"                     # abbreviation; carries no tone to compare
)

# The same words with diacritics removed, for the deliberately loose fallback.
.vn_prefix_ascii <- c("thanh pho", "thi tran", "thi xa", "huyen", "phuong",
                      "tinh", "quan", "xa", "tp")

# Lowercase, then reduce every run of punctuation or whitespace to one space so
# that prefixes can be matched as whole leading words. Diacritics are kept.
.vn_words <- function(x) {
  x <- stringi::stri_trans_nfc(as.character(x))
  x <- stringi::stri_trans_tolower(x)
  x <- stringi::stri_replace_all_regex(x, "[^\\p{L}\\p{N}]+", " ")
  stringi::stri_trim_both(x)
}

# Remove one leading administrative word. `words` must be output of
# `.vn_words()`; `prefixes` decides whether tone marks have to agree. A prefix
# is only removed when something is left behind to match on.
.vn_cut_prefix <- function(words, prefixes) {
  for (p in prefixes) {
    hit <- which(stringi::stri_startswith_fixed(words, paste0(p, " ")))
    if (!length(hit)) next
    rest <- stringi::stri_sub(words[hit], stringi::stri_length(p) + 2L)
    keep <- nzchar(rest)
    words[hit[keep]] <- rest[keep]
  }
  words
}

# Tone-preserving key. Units differing only by diacritics stay distinct.
.vn_norm <- function(x) {
  w <- .vn_cut_prefix(.vn_words(x), .vn_prefix_words)
  stringi::stri_replace_all_fixed(w, " ", "")
}

# ASCII key. The historical normalization, with prefix removal corrected to run
# on tone-marked word boundaries instead of on punctuation-stripped text.
.vn_key <- function(x) {
  ascii <- stringi::stri_trans_general(.vn_norm(x), "Latin-ASCII")
  tolower(gsub("[^a-zA-Z0-9]", "", ascii))
}

# ASCII key that also removes a leading administrative word written without
# diacritics, as in "Tinh Cao Bang". Destructive by construction -- stripped of
# tones it cannot tell that prefix from the first syllable of Tinh Bien -- so
# it is consulted only after `.vn_norm()` and `.vn_key()` have both failed.
.vn_key_loose <- function(x) {
  ascii <- tolower(stringi::stri_trans_general(.vn_words(x), "Latin-ASCII"))
  gsub("[^a-z0-9]", "", .vn_cut_prefix(ascii, .vn_prefix_ascii))
}
