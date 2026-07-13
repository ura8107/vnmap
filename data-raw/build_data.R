library(sf)

raw <- st_read("data-raw/source/geoBoundaries-VNM-ADM1_simplified.geojson", quiet = TRUE)
raw <- st_make_valid(raw)

ascii <- function(x) gsub("[^a-z0-9]", "", tolower(stringi::stri_trans_general(x, "Latin-ASCII")))
raw$key <- ascii(raw$shapeName)

# geoBoundaries represents the 2008-era Ha Tay separately. It became part of
# Ha Noi in 2008; unioning it first produces the subsequent 63-unit geography.
raw$key[raw$key == "hatay"] <- "hanoi"
raw$key[raw$key == "condao"] <- "bariavungtau"
old <- aggregate(raw["geometry"], list(key = raw$key), function(x) x[1])

old_meta <- read.csv("data-raw/provinces_63.csv", stringsAsFactors = FALSE,
                     check.names = FALSE, colClasses = "character")
old <- st_as_sf(merge(old_meta, old, by = "key", all.x = TRUE, sort = FALSE))
stopifnot(nrow(old) == 63L, !any(st_is_empty(old)))
old <- st_transform(old, 3405)
old <- old[c("code", "iso", "name_vi", "name_en", "type", "geometry")]

mergers <- read.csv("data-raw/provinces_34.csv", stringsAsFactors = FALSE,
                    check.names = FALSE, colClasses = "character", na.strings = "")
pieces <- do.call(rbind, lapply(seq_len(nrow(mergers)), function(i) {
  members <- strsplit(mergers$members[i], "\\+")[[1]]
  cbind(mergers[rep(i, length(members)), ], member_code = members)
}))
pieces <- st_as_sf(merge(pieces, transform(old, member_code = code)[c("member_code", "geometry")], by = "member_code"))
current <- do.call(rbind, lapply(seq_len(nrow(mergers)), function(i) {
  subset <- pieces[pieces$code == mergers$code[i], ]
  st_sf(mergers[i, c("code", "iso", "name_vi", "name_en", "type", "aliases")],
        geometry = st_union(st_geometry(subset)), crs = st_crs(subset))
}))
current <- current[order(as.integer(current$code)), ]
stopifnot(nrow(current) == 34L, nrow(pieces) == 63L)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(old, "inst/extdata/provinces_63.rds", compress = "xz")
saveRDS(current[c("code", "iso", "name_vi", "name_en", "type", "geometry")],
        "inst/extdata/provinces.rds", compress = "xz")
saveRDS(transform(old_meta, aliases = paste(name_vi, name_en, sep = "|"))[
  c("code", "iso", "name_vi", "name_en", "type", "aliases")],
  "inst/extdata/provinces_63_info.rds")
saveRDS(current[c("code", "iso", "name_vi", "name_en", "type", "aliases")],
        "inst/extdata/provinces_info.rds")
