# Build the bundled national industrial-park registry from a dated
# OpenStreetMap snapshot.
#
# The snapshot is a name-matched Overpass extract: every Vietnamese feature
# whose name mentions an industrial park, export-processing zone, high-tech
# park, or industrial cluster. Two kinds of evidence are mined from it.
#
#   site features      the mapped extent of a park (landuse=industrial or
#                      industrial=industrial_park). These give a boundary.
#   reference features anything else that names a park - an entrance gate, a
#                      bus stop, an internal road, a plant inside the park.
#                      These do not give a boundary but they do place the park
#                      to within a few hundred metres, so a park that OSM has
#                      not drawn still earns a registry record.
#
# Features are reduced to one row per park: names are normalized to a park key,
# keys are clustered spatially inside each province, and the best geometry in
# each cluster wins. Every row keeps the OSM elements it was built from.
#
# Set VNMAP_OSM_FILE to reuse a saved Overpass JSON response.

if (!requireNamespace("sf", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE) ||
    !requireNamespace("stringi", quietly = TRUE)) {
  stop("Packages 'sf', 'jsonlite' and 'stringi' are required.")
}

snapshot_date <- as.Date("2026-08-11")
cluster_radius_m <- 5000
input <- Sys.getenv("VNMAP_OSM_FILE", unset = "")
if (!nzchar(input)) {
  snapshot <- "data-raw/source/osm-industrial-parks-2026-08-11.json.gz"
  if (file.exists(snapshot)) input <- snapshot
}
if (!nzchar(input)) {
  input <- tempfile(fileext = ".json")
  query <- paste0(
    '[out:json][timeout:150];area["ISO3166-1"="VN"]',
    '[admin_level=2]->.vn;nwr(area.vn)["name"~',
    '"(Khu công nghiệp|Khu cong nghiep|Khu chế xuất|Industrial Park|',
    'Industrial Zone|Export Processing Zone|KCN | IZ$)",i];out center tags geom;'
  )
  endpoint <- "https://overpass.kumi.systems/api/interpreter"
  utils::download.file(paste0(endpoint, "?data=", utils::URLencode(query)), input,
                       mode = "wb", quiet = TRUE)
}

con <- if (grepl("\\.gz$", input)) gzfile(input, "rt") else file(input, "rt")
json <- paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "")
close(con)
raw <- jsonlite::fromJSON(json, simplifyVector = FALSE)$elements

# The snapshot is UTF-8 whatever the locale of the machine running this build,
# so declare it rather than letting a C locale hide the diacritics.
as_utf8 <- function(x) {
  x <- as.character(x)
  Encoding(x) <- "UTF-8"
  x
}
tag <- function(x, key, default = NA_character_) {
  value <- x$tags[[key]]
  if (is.null(value) || !nzchar(as.character(value))) default else as_utf8(value)
}
ascii <- function(x) stringi::stri_trans_general(as_utf8(x), "Latin-ASCII")
trim_punct <- function(x) {
  stringi::stri_replace_all_regex(as_utf8(x), "^[\\p{P}\\p{S}]+|[\\p{P}\\p{S}]+$", "")
}

## ---------------------------------------------------------------------------
## Park name parsing
##
## `parse_name()` works on whitespace tokens so that the diacritic-free copy
## used for matching stays aligned with the original words whatever normal form
## the OSM string arrives in. It finds the category keyword, keeps the words
## that follow it up to the first address or route marker, and returns the park
## label with its diacritics intact plus a diacritic-free matching key.
## ---------------------------------------------------------------------------

keywords <- rbind(
  data.frame(phrase = c("khu che xuat", "kcx", "export processing zone"),
             category = "export_processing_zone", prefix = "Khu chế xuất"),
  data.frame(phrase = c("khu cong nghe cao", "khu cnc"),
             category = "high_tech_park", prefix = "Khu công nghệ cao"),
  data.frame(phrase = c("cum cong nghiep", "cum tieu thu cong nghiep"),
             category = "industrial_cluster", prefix = "Cụm công nghiệp"),
  data.frame(phrase = c("khu cong nghiep", "kcn", "industrial park",
                        "industrial zone", "industrial complex"),
             category = "industrial_park", prefix = "Khu công nghiệp")
)
keywords$prefix <- as_utf8(keywords$prefix)
keywords$words <- strsplit(keywords$phrase, " ", fixed = TRUE)

# Address and route markers. Vietnamese park names reuse many of the same
# syllables once diacritics are gone - "Hai Duong" against "duong" for a street,
# "Noi Bai" against "noi bo" - so a marker only cuts the label in the shape it
# actually takes in an address.
#
#   cut_phrases     two words in sequence ("doi dien", "thanh pho")
#   cut_words       function words that never open a park name
#   numbered_words  a marker followed by a number or a plot code ("lo C7")
#   admin_words     a unit prefix, which cuts only when a name follows it
cut_phrases <- list(c("doi", "dien"), c("nga", "ba"), c("nga", "tu"),
                    c("ben", "xe"), c("dia", "chi"), c("cong", "ty"),
                    c("chi", "nhanh"), c("giai", "doan"), c("head", "office"),
                    c("thanh", "pho"), c("thi", "tran"), c("noi", "bo"),
                    c("khu", "pho"), c("truoc", "loi"))
cut_words <- c("truoc", "qua", "gan", "thuoc", "voi", "va", "cty", "ty")
numbered_words <- c("km", "to", "lo", "so", "ap", "cong", "duong", "ngo",
                    "pho", "tuyen", "phong", "nha", "tang", "lau")
admin_words <- c("xa", "phuong", "huyen", "tp")

roman <- c(i = "1", ii = "2", iii = "3", iv = "4", v = "5", vi = "6",
           vii = "7", viii = "8", ix = "9", x = "10")

parse_name <- function(name) {
  if (is.na(name)) return(NULL)
  words <- strsplit(gsub("[[:space:]]+", " ", trimws(name)), " ", fixed = TRUE)[[1]]
  if (!length(words)) return(NULL)
  plain <- tolower(ascii(words))
  bare <- gsub("^[^a-z0-9]+|[^a-z0-9]+$", "", plain)
  # A word carrying inner punctuation ("c-7-cn", "d1.01") belongs to an address.
  broken <- grepl("[^a-z0-9]", bare)
  # A word closed by punctuation ends the label after that word; a word opened
  # by punctuation - "(Melinh" - starts an aside and is not part of the label.
  closes <- grepl("[^[:alnum:]]$", plain)
  opens <- grepl("^[^[:alnum:]]", plain)

  hit <- NULL
  for (i in seq_len(nrow(keywords))) {
    w <- keywords$words[[i]]
    n <- length(w)
    starts <- which(bare == w[1])
    for (s in starts) {
      if (s + n - 1L > length(bare)) next
      if (!identical(bare[s:(s + n - 1L)], w)) next
      if (is.null(hit) || s < hit$start) {
        hit <- list(start = s, end = s + n - 1L, row = i)
      }
      break
    }
  }
  if (is.null(hit)) return(NULL)

  taken <- integer(0)
  k <- hit$end
  while (k < length(bare) && length(taken) < 5L) {
    k <- k + 1L
    word <- bare[k]
    if (!nzchar(word) || broken[k] || opens[k]) break
    if (word %in% cut_words) break
    if (grepl("^[0-9]+m$", word)) break
    nxt <- if (k < length(bare)) bare[k + 1L] else ""
    if (word %in% numbered_words &&
        (grepl("^[a-z]?[0-9]", nxt) || identical(nxt, "so"))) break
    if (identical(word, "duong") && !length(taken)) break
    if (word %in% admin_words && nzchar(nxt) && !closes[k]) break
    if (any(vapply(cut_phrases, function(a) {
      identical(word, a[1]) && identical(nxt, a[2])
    }, logical(1)))) break
    taken <- c(taken, k)
    if (closes[k]) break
  }
  # A trailing three-digit run is a house number, not a park phase.
  if (length(taken) > 1L && grepl("^[0-9]{3,}$", bare[taken[length(taken)]])) {
    taken <- taken[-length(taken)]
  }
  trailing_noise <- c("cong", "km", "lo", "so", "nha")
  while (length(taken) && bare[taken[length(taken)]] %in% trailing_noise) {
    taken <- taken[-length(taken)]
  }
  if (!length(taken)) return(NULL)

  label <- paste(trim_punct(words[taken]), collapse = " ")
  parts <- bare[taken]
  last <- parts[length(parts)]
  if (last %in% names(roman)) parts[length(parts)] <- roman[[last]]
  # Vietnamese writes both "KCN Nhơn Trạch 1" and "KCN 1 Nhơn Trạch".
  if (length(parts) > 1L && grepl("^[0-9]+$", parts[1])) {
    parts <- c(parts[-1], parts[1])
  }
  key <- paste(parts, collapse = " ")
  if (!nzchar(key) || !grepl("[a-z]", key)) return(NULL)
  list(label = label, key = key, category = keywords$category[hit$row],
       prefix = keywords$prefix[hit$row], leading = hit$start == 1L)
}

## ---------------------------------------------------------------------------
## Feature table
## ---------------------------------------------------------------------------

parsed <- lapply(raw, function(x) parse_name(tag(x, "name")))
keep <- !vapply(parsed, is.null, logical(1))
raw <- raw[keep]
parsed <- parsed[keep]

exclusion_file <- "data-raw/industrial-parks-exclusions.csv"
exclusions <- utils::read.csv(exclusion_file, colClasses = "character")

is_site <- vapply(raw, function(x) {
  identical(tag(x, "landuse", ""), "industrial") ||
    identical(tag(x, "industrial", ""), "industrial_park")
}, logical(1))

# A named plant, depot or office that merely sits in a park is evidence of the
# park's location, never the park itself.
feature_names <- tolower(ascii(vapply(raw, tag, "", key = "name", default = "")))
facility <- grepl("^(nha may|tram |cong ty|cty|kho |chi nhanh|xuong)", feature_names)
is_site <- is_site & !facility

geometry_of <- function(x) {
  if (!is.null(x$geometry) && length(x$geometry) >= 4L) {
    xy <- do.call(rbind, lapply(x$geometry, function(p) c(p$lon, p$lat)))
    closed <- isTRUE(all.equal(xy[1, ], xy[nrow(xy), ]))
    if (closed) return(sf::st_polygon(list(xy)))
    return(sf::st_linestring(xy))
  }
  if (!is.null(x$geometry) && length(x$geometry) >= 2L) {
    xy <- do.call(rbind, lapply(x$geometry, function(p) c(p$lon, p$lat)))
    return(sf::st_linestring(xy))
  }
  lon <- if (!is.null(x$lon)) x$lon else if (!is.null(x$center$lon)) {
    x$center$lon
  } else mean(c(x$bounds$minlon, x$bounds$maxlon))
  lat <- if (!is.null(x$lat)) x$lat else if (!is.null(x$center$lat)) {
    x$center$lat
  } else mean(c(x$bounds$minlat, x$bounds$maxlat))
  sf::st_point(c(lon, lat))
}

geoms <- sf::st_sfc(lapply(raw, geometry_of), crs = 4326)
points <- suppressWarnings(sf::st_point_on_surface(geoms))

features <- data.frame(
  osm_type = vapply(raw, function(x) x$type, ""),
  osm_id = vapply(raw, function(x) as.character(x$id), ""),
  name = vapply(raw, tag, "", key = "name", default = ""),
  name_en = vapply(raw, tag, NA_character_, key = "name:en"),
  alt_name = vapply(raw, tag, NA_character_, key = "alt_name"),
  short_name = vapply(raw, tag, NA_character_, key = "short_name"),
  operator = vapply(raw, tag, NA_character_, key = "operator"),
  label = vapply(parsed, `[[`, "", "label"),
  park_key = vapply(parsed, `[[`, "", "key"),
  category = vapply(parsed, `[[`, "", "category"),
  prefix = vapply(parsed, `[[`, "", "prefix"),
  leading = vapply(parsed, `[[`, logical(1), "leading"),
  is_site = is_site,
  under_construction = vapply(raw, function(x) {
    !is.na(tag(x, "construction")) || identical(tag(x, "landuse", ""), "construction")
  }, logical(1)),
  stringsAsFactors = FALSE
)
features$osm_url <- paste0("https://www.openstreetmap.org/",
                           features$osm_type, "/", features$osm_id)
features$is_polygon <- vapply(geoms, function(g) {
  inherits(g, c("POLYGON", "MULTIPOLYGON"))
}, logical(1))
stopifnot(length(geoms) == nrow(features), length(points) == nrow(features))

## ---------------------------------------------------------------------------
## Administrative assignment
## ---------------------------------------------------------------------------

current <- sf::st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
former <- sf::st_transform(readRDS("inst/extdata/provinces_63.rds"), 4326)
communes <- sf::st_transform(readRDS("inst/extdata/communes.rds"), 4326)
info <- readRDS("inst/extdata/provinces_info.rds")
info_63 <- readRDS("inst/extdata/provinces_63_info.rds")

assign_code <- function(pts, boundaries) {
  hits <- suppressMessages(sf::st_intersects(pts, boundaries))
  out <- vapply(hits, function(i) if (length(i)) i[1] else NA_integer_, integer(1))
  ifelse(is.na(out), NA_character_, boundaries$code[out])
}
nearest_code <- function(pts, boundaries) {
  idx <- suppressMessages(sf::st_nearest_feature(pts, boundaries))
  boundaries$code[idx]
}

features$province_code <- assign_code(points, current)
offshore <- is.na(features$province_code)
if (any(offshore)) {
  features$province_code[offshore] <- nearest_code(points[offshore], current)
}
# The 63-unit layer is derived from a coarser public-domain source, so a point
# near a former boundary can fall in a unit that did not merge into the park's
# current province. Constrain the former assignment to the merger members of
# the current unit and, where it conflicts, take the nearest member.
membership <- utils::read.csv("data-raw/provinces_34.csv", colClasses = "character")
members_of <- setNames(strsplit(membership$members, "+", fixed = TRUE),
                       membership$code)
features$former_province_code <- assign_code(points, former)
allowed <- vapply(seq_len(nrow(features)), function(i) {
  member <- members_of[[features$province_code[i]]]
  !is.na(features$former_province_code[i]) &&
    features$former_province_code[i] %in% member
}, logical(1))
if (any(!allowed)) {
  for (i in which(!allowed)) {
    member <- members_of[[features$province_code[i]]]
    candidates <- former[former$code %in% member, , drop = FALSE]
    features$former_province_code[i] <- nearest_code(points[i], candidates)
  }
}

# An exclusion with an empty province code applies nationally.
excluded <- rep(FALSE, nrow(features))
for (i in seq_len(nrow(exclusions))) {
  hit <- features$category == exclusions$category[i] &
    features$park_key == exclusions$park_key[i]
  if (!is.na(exclusions$province_code[i]) && nzchar(exclusions$province_code[i])) {
    hit <- hit & features$province_code == exclusions$province_code[i]
  }
  hit[is.na(hit)] <- FALSE
  excluded <- excluded | hit
}
features <- features[!excluded, , drop = FALSE]
geoms <- geoms[!excluded]
points <- points[!excluded]
row.names(features) <- NULL

## ---------------------------------------------------------------------------
## Reduce features to one row per park
## ---------------------------------------------------------------------------

group <- paste(features$category, features$province_code, features$park_key,
               sep = "\r")
clusters <- integer(nrow(features))
next_id <- 0L
for (g in unique(group)) {
  idx <- which(group == g)
  if (length(idx) == 1L) {
    next_id <- next_id + 1L
    clusters[idx] <- next_id
    next
  }
  d <- suppressMessages(sf::st_distance(points[idx]))
  units(d) <- NULL
  membership <- stats::cutree(stats::hclust(stats::as.dist(d), method = "single"),
                              h = cluster_radius_m)
  clusters[idx] <- next_id + membership
  next_id <- next_id + max(membership)
}

# Mappers write "binh Long" as often as "Bình Long"; lift words that are wholly
# lower case and leave acronyms such as VSIP alone.
title_label <- function(x) {
  words <- strsplit(x, " ", fixed = TRUE)[[1]]
  lower <- words == stringi::stri_trans_tolower(words)
  words[lower] <- stringi::stri_trans_totitle(words[lower])
  paste(words, collapse = " ")
}

collapse <- function(x) {
  x <- unique(x[!is.na(x) & nzchar(x)])
  if (!length(x)) NA_character_ else paste(x, collapse = "|")
}

build_row <- function(idx) {
  rows <- features[idx, , drop = FALSE]
  site <- idx[rows$is_site]
  poly <- idx[rows$is_site & rows$is_polygon]
  if (length(poly)) {
    geom <- sf::st_union(geoms[poly])
    geometry_type <- "polygon"
    location_accuracy <- "site"
    geometry_source <- "osm_site_polygon"
  } else if (length(site)) {
    geom <- suppressWarnings(sf::st_centroid(sf::st_union(points[site])))
    geometry_type <- "point"
    location_accuracy <- "locality"
    geometry_source <- "osm_site_point"
  } else {
    geom <- suppressWarnings(sf::st_centroid(sf::st_union(points[idx])))
    geometry_type <- "point"
    location_accuracy <- "locality"
    geometry_source <- "osm_reference_point"
  }
  ranked <- rows[order(!rows$is_site, !rows$leading, nchar(rows$name)), ,
                 drop = FALSE]
  label <- ranked$label[1]
  if (length(site) && ranked$leading[1]) {
    # A drawn site carries the mapper's own name for the park; keep it.
    name_vi <- ranked$name[1]
  } else {
    name_vi <- paste(ranked$prefix[1], title_label(label))
  }
  aliases <- collapse(c(name_vi, rows$name[rows$leading], rows$name_en,
                        rows$alt_name, rows$short_name))
  list(
    name_vi = name_vi,
    name_en = collapse(rows$name_en),
    short_name = ascii(title_label(label)),
    aliases = aliases,
    category = rows$category[1],
    park_key = rows$park_key[1],
    province_code = rows$province_code[1],
    former_province_code = names(sort(table(rows$former_province_code),
                                      decreasing = TRUE))[1],
    status = if (any(rows$under_construction)) "under_construction" else "unknown",
    developer = collapse(rows$operator)[1],
    geometry_type = geometry_type,
    location_accuracy = location_accuracy,
    geometry_source = geometry_source,
    feature_count = nrow(rows),
    osm_refs = paste(rows$osm_url, collapse = "|"),
    source_url = rows$osm_url[order(!rows$is_site, nchar(rows$name))][1],
    geom = geom
  )
}

# One park, one row. A key that survives only as reference features in several
# places is one park seen from several bus stops, not several parks: keep the
# best-evidenced cluster, and drop reference-only clusters entirely when the
# same key is already drawn as a site somewhere in the province.
groups <- split(seq_len(nrow(features)), clusters)
has_site <- vapply(groups, function(idx) any(features$is_site[idx]), logical(1))
cluster_group <- vapply(groups, function(idx) group[idx[1]], "")
sized <- lengths(groups)
keep_cluster <- rep(TRUE, length(groups))
for (g in unique(cluster_group)) {
  members <- which(cluster_group == g)
  if (length(members) == 1L) next
  sited <- members[has_site[members]]
  if (length(sited)) {
    keep_cluster[setdiff(members, sited)] <- FALSE
  } else {
    keep_cluster[members[-which.max(sized[members])]] <- FALSE
  }
}
groups <- groups[keep_cluster]

# "KCN VSIP" beside "KCN VSIP Bac Ninh" in one province is the shorter way of
# writing the same park. A reference-only cluster whose key merely opens the key
# of a better-evidenced cluster adds no park.
cluster_key <- vapply(groups, function(idx) features$park_key[idx[1]], "")
cluster_province <- vapply(groups, function(idx) features$province_code[idx[1]], "")
cluster_sited <- vapply(groups, function(idx) any(features$is_site[idx]), logical(1))
prefix_of <- function(short, long) {
  a <- strsplit(short, " ", fixed = TRUE)[[1]]
  b <- strsplit(long, " ", fixed = TRUE)[[1]]
  length(a) < length(b) && identical(a, b[seq_along(a)])
}
# The reverse case: a drawn park whose key is extended by a street or block
# reference ("Dai An" against "Dai An pho Xuan Thi").
address_tail <- function(long, short) {
  if (!prefix_of(short, long)) return(FALSE)
  a <- strsplit(short, " ", fixed = TRUE)[[1]]
  b <- strsplit(long, " ", fixed = TRUE)[[1]]
  b[length(a) + 1L] %in% c(numbered_words, admin_words)
}
redundant <- vapply(seq_along(groups), function(i) {
  if (cluster_sited[i]) return(FALSE)
  peers <- which(cluster_province == cluster_province[i] & seq_along(groups) != i)
  if (any(vapply(cluster_key[peers], prefix_of, logical(1),
                 short = cluster_key[i]))) return(TRUE)
  sited_peers <- peers[cluster_sited[peers]]
  any(vapply(cluster_key[sited_peers], address_tail, logical(1),
             long = cluster_key[i]))
}, logical(1))
groups <- groups[!redundant]

built <- lapply(groups, build_row)
parks <- do.call(rbind, lapply(built, function(x) {
  as.data.frame(x[setdiff(names(x), "geom")], stringsAsFactors = FALSE)
}))
geometry <- sf::st_sfc(lapply(built, function(x) sf::st_geometry(x$geom)[[1]]),
                       crs = 4326)
parks <- sf::st_sf(parks, geometry = geometry)
parks <- sf::st_make_valid(parks)

# A multi-part union of adjacent phases stays one park; record the type after
# the union so downstream filters see the truth.
gtype <- tolower(as.character(sf::st_geometry_type(parks)))
parks$geometry_type <- ifelse(gtype %in% c("polygon", "multipolygon"),
                              "polygon", "point")

parks$name_en[!is.na(parks$name_en)] <-
  vapply(strsplit(parks$name_en[!is.na(parks$name_en)], "|", fixed = TRUE),
         `[[`, "", 1L)
parks$developer[!is.na(parks$developer)] <-
  vapply(strsplit(parks$developer[!is.na(parks$developer)], "|", fixed = TRUE),
         `[[`, "", 1L)

parks$province_en <- info$name_en[match(parks$province_code, info$code)]
parks$former_province_en <- info_63$name_en[match(parks$former_province_code,
                                                  info_63$code)]
if (anyNA(parks$province_code)) {
  stop("Some parks could not be assigned to a current province.")
}

representative <- suppressWarnings(sf::st_point_on_surface(parks))
commune_hit <- suppressMessages(sf::st_intersects(representative, communes))
commune_index <- vapply(commune_hit, function(i) if (length(i)) i[1] else NA_integer_,
                        integer(1))
parks$commune_code <- ifelse(is.na(commune_index), NA_character_,
                             communes$code[commune_index])
parks$commune_name <- ifelse(is.na(commune_index), NA_character_,
                             communes$name_vi[commune_index])

area <- rep(NA_real_, nrow(parks))
is_polygon <- parks$geometry_type == "polygon"
if (any(is_polygon)) {
  area[is_polygon] <- as.numeric(sf::st_area(parks[is_polygon, ])) / 10000
}
parks$area_ha <- round(area, 3)

coords <- sf::st_coordinates(representative)
parks$lon <- round(coords[, "X"], 6)
parks$lat <- round(coords[, "Y"], 6)

slug <- function(x) {
  x <- tolower(ascii(x))
  x <- gsub("[^a-z0-9]+", "-", x)
  gsub("^-|-$", "", x)
}
category_tag <- c(industrial_park = "IP", export_processing_zone = "EPZ",
                  high_tech_park = "HTP", industrial_cluster = "IC")
parks$id <- paste0("VN-", category_tag[parks$category], "-", parks$province_code,
                   "-", slug(parks$park_key))
dupes <- duplicated(parks$id)
if (any(dupes)) {
  seqno <- stats::ave(parks$id, parks$id, FUN = seq_along)
  parks$id <- ifelse(duplicated(parks$id) | duplicated(parks$id, fromLast = TRUE),
                     paste0(parks$id, "-", seqno), parks$id)
}

parks$source_date <- as.Date(NA_character_)
parks$verified_on <- snapshot_date
parks <- parks[order(parks$province_code, parks$category, parks$park_key), ]
row.names(parks) <- NULL
parks <- parks[c(
  "id", "name_vi", "name_en", "short_name", "aliases", "park_key", "category",
  "province_code", "province_en", "former_province_code", "former_province_en",
  "commune_code", "commune_name", "status", "area_ha", "developer",
  "geometry_type", "location_accuracy", "geometry_source", "feature_count",
  "osm_refs", "lon", "lat", "source_url", "source_date", "verified_on",
  "geometry"
)]
sf::st_crs(parks) <- 4326

registry <- sf::st_drop_geometry(parks)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(parks, "inst/extdata/industrial_parks.rds", compress = "xz")
saveRDS(registry, "inst/extdata/industrial_park_registry.rds", compress = "xz")

baseline <- utils::read.csv("data-raw/industrial-park-official-baseline.csv",
                            stringsAsFactors = FALSE)
saveRDS(baseline, "inst/extdata/industrial_park_baseline.rds", compress = "xz")

# write.csv() renders UTF-8 strings as <U+XXXX> escapes when the build runs in a
# C locale, so the reviewable mirror is written as bytes instead.
write_utf8_csv <- function(x, path) {
  quoted <- lapply(x, function(column) {
    text <- as.character(column)
    text[is.na(text)] <- ""
    if (is.numeric(column)) return(text)
    paste0("\"", gsub("\"", "\"\"", text, fixed = TRUE), "\"")
  })
  con <- file(path, "wb")
  on.exit(close(con))
  writeLines(c(paste0("\"", names(x), "\"", collapse = ","),
               do.call(paste, c(quoted, sep = ","))), con, useBytes = TRUE)
}
write_utf8_csv(registry, "data-raw/industrial-parks-registry.csv")

official <- baseline$value[baseline$metric == "established_industrial_parks"]
counted <- sum(registry$category %in% c("industrial_park", "export_processing_zone"))
audit <- data.frame(
  metric = c("official_established_baseline", "registry_records",
             "industrial_park_and_epz_records", "unmapped_against_baseline",
             "site_boundary_records", "locality_point_records",
             "provinces_covered", "communes_identified"),
  value = c(official, nrow(registry), counted, max(official - counted, 0L),
            sum(registry$location_accuracy == "site"),
            sum(registry$location_accuracy == "locality"),
            length(unique(registry$province_code)),
            sum(!is.na(registry$commune_code)))
)
utils::write.csv(audit, "data-raw/industrial-parks-audit.csv", row.names = FALSE)

message("Built ", nrow(registry), " registry records (",
        sum(registry$location_accuracy == "site"), " with a mapped boundary); ",
        "official established baseline gap: ", official - counted, ".")
