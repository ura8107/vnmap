# Offline reconciliation of complete source snapshots. Run after
# build_industrial_parks.R. Never turn a national aggregate into missing rows.
library(sf)
library(jsonlite)
library(stringi)
sf_use_s2(FALSE)
root <- "data-raw/source/industrial-park-evidence"
read_chars <- function(file) read.csv(file, colClasses = "character", na.strings = "")
norm <- function(x) {
  x[is.na(x)] <- ""
  x <- tolower(stri_trans_general(x, "Latin-ASCII"))
  trimws(gsub(" +", " ", gsub("[^a-z0-9]+", " ", x)))
}
park_key <- function(x) {
  x <- sub("/.*$", "", x)
  x <- norm(x)
  x <- gsub("\\bviet nam singapore\\b", "vsip", x)
  x <- sub("^.*? - ", "", x)
  x <- sub("^(khu cong nghiep|khu cn|kcn|khu che xuat|kcx|cum cong nghiep|ccn) +", "", x)
  x <- sub(" +(industrial park|industrial zone|export processing zone|industrial cluster)$", "", x)
  roman <- c("i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x")
  for (i in seq_along(roman)) x <- gsub(paste0("\\b", roman[i], "\\b"), as.character(i), x)
  trimws(x)
}
category <- function(x) {
  x <- norm(x)
  ifelse(grepl("cum cong nghiep|\\bccn\\b", x), "industrial_cluster",
    ifelse(grepl("khu cong nghe cao", x), "hi_tech_park",
    ifelse(grepl("khu che xuat|\\bkcx\\b", x), "export_processing_zone",
    ifelse(grepl("khu cong nghiep|\\bkcn\\b", x), "industrial_park", "unclassified"))))
}
parks <- readRDS("inst/extdata/industrial_parks.rds")
# Make this build idempotent: previous supplements are reconstructed from evidence.
parks <- parks[parks$source != "Invest Vietnam + OpenStreetMap", ]
parks$geometry_observed_on <- parks$verified_on
parks$status[parks$attribute_source == "osm" & parks$status == "operational"] <- "unknown"
current <- read_chars("data-raw/provinces_34.csv")
old <- read_chars("data-raw/provinces_63.csv")
members <- strsplit(current$members, "+", fixed = TRUE)
old_to_new <- setNames(rep(current$code, lengths(members)), unlist(members))
province_from_text <- function(text) {
  text <- paste0(" ", norm(text), " ")
  hits <- vapply(norm(old$name_en), function(n) grepl(paste0(" ", n, " "), text, fixed = TRUE), logical(1))
  current_hits <- vapply(norm(current$name_en), function(n) grepl(paste0(" ", n, " "), text, fixed = TRUE), logical(1))
  codes <- unique(c(unname(old_to_new[old$code[hits]]), current$code[current_hits]))
  if (length(codes) == 1L) codes else NA_character_
}
province_from_location <- function(text) {
  # Transport corridors mention several provinces that are not the location.
  # Only an explicitly labelled province is used from narrative text.
  text <- norm(text)
  labels <- c(norm(old$name_en), norm(current$name_en))
  codes <- c(unname(old_to_new[old$code]), current$code)
  hit <- vapply(labels, function(n) grepl(paste0("\\btinh ", n, "\\b"), text), logical(1))
  found <- unique(codes[hit])
  if (length(found) == 1L) found else NA_character_
}
feed <- fromJSON(fromJSON(file.path(root, "investvietnam-2026-09-10.json"))$d)
location <- read_chars(file.path(root, "investvietnam-locations-2026-09-10.csv"))
stopifnot(nrow(feed) == nrow(location), !anyDuplicated(feed$id), !anyDuplicated(location$source_id),
          setequal(feed$id, location$source_id))
official <- data.frame(
  source_record_id = paste0("investvietnam-", feed$id), name_vi = feed$title,
  category = category(feed$title),
  province_code = vapply(location$location_text[match(feed$id, location$source_id)], province_from_location, ""),
  source = "Invest Vietnam", source_url = paste0("https://investvietnam.gov.vn", feed$link),
  retrieved_on = "2026-09-10", stringsAsFactors = FALSE)
# URL province prefixes offer location evidence when the location field is empty.
for (i in which(is.na(official$province_code))) {
  slug <- sub(".*/", "", feed$link[i])
  prefix <- strsplit(slug, "---", fixed = TRUE)[[1]][1]
  official$province_code[i] <- province_from_text(prefix)
}
official$location_text <- location$location_text[match(feed$id, location$source_id)]
official$reported_longitude <- as.numeric(feed$lng)
official$reported_latitude <- as.numeric(feed$lat)
zero <- official$reported_longitude == 0 | official$reported_latitude == 0
official$reported_longitude[zero] <- official$reported_latitude[zero] <- NA_real_
official$key <- park_key(official$name_vi)
# Several feed titles prefix a province before the actual designation.
official$key <- park_key(sub("^.*?((KCN|Khu công nghiệp|CCN|Cụm công nghiệp) )", "\\1", official$name_vi))
official$province_source_url <- ifelse(is.na(official$province_code), NA_character_, official$source_url)
official$province_match_method <- ifelse(is.na(official$province_code), "unknown", "official_location_or_url_prefix")
discovery <- read_chars(file.path(root, "kcn-kkt-2026-09-10.csv"))
discovery_keys <- park_key(discovery$ten)
discovery_provinces <- vapply(discovery$tinhTen, province_from_text, "")
# Three-source identity corroboration: an official name, a uniquely matching
# discovery province, and the mapped OSM site. This does not verify legal status.
for (i in which(is.na(official$province_code))) {
  h <- which(discovery_keys == official$key[i] & category(discovery$ten) == official$category[i])
  if (length(h) == 1L && !is.na(discovery_provinces[h])) {
    official$province_code[i] <- discovery_provinces[h]
    official$province_source_url[i] <- discovery$source_url[h]
    official$province_match_method[i] <- "unique_discovery_name_province_unverified"
  }
}

branch <- read_chars(file.path(root, "branch-registry-29cc12f.csv"))
branch$key <- park_key(branch$name_vi)
branch$lon <- as.numeric(branch$lon); branch$lat <- as.numeric(branch$lat)
aliases <- function(p) lapply(seq_len(nrow(p)), function(i) unique(park_key(c(
  p$name_vi[i], p$name_en[i], strsplit(ifelse(is.na(p$aliases[i]), "", p$aliases[i]), "|", fixed = TRUE)[[1]]))))
map_keys <- aliases(parks)
lookup <- function(key, province, cat, keys = map_keys, p = parks) {
  which(vapply(keys, function(k) nzchar(key) && key %in% k, logical(1)) &
    (is.na(province) | p$province_code == province) & p$category == cat)
}
official$map_id <- NA_character_
official$match_method <- "unresolved"
for (i in seq_len(nrow(official))) {
  hit <- lookup(official$key[i], official$province_code[i], official$category[i])
  if (length(hit) == 1L && !is.na(official$province_code[i])) {
    official$map_id[i] <- parks$id[hit]
    official$match_method[i] <- "exact_alias_and_source_province"
  } else if (length(hit)) official$match_method[i] <- "review_name_or_province"
}
# The unmerged branch contributes only locality points corroborated by the
# official list and its province. Its older geometry never replaces main.
added <- list()
for (i in which(is.na(official$map_id) & !is.na(official$province_code))) {
  h <- which(branch$key == official$key[i] & branch$province_code == official$province_code[i] &
               branch$category == official$category[i])
  if (length(h) != 1L) next
  b <- branch[h, ]
  refs <- strsplit(b$osm_refs, "|", fixed = TRUE)[[1]]
  osm_ids <- gsub("https://www.openstreetmap.org/([a-z]+)/([0-9]+)", "osm_\\1_\\2", refs)
  existing <- which(vapply(strsplit(parks$osm_ids, "|", fixed = TRUE),
                           function(x) any(x %in% osm_ids), logical(1)))
  if (length(existing)) {
    if (length(existing) == 1L && parks$category[existing] == official$category[i]) {
      official$map_id[i] <- parks$id[existing]
      official$match_method[i] <- "official_name_province_and_shared_osm_reference"
    }
    next
  }
  if (!is.finite(b$lon) || !is.finite(b$lat)) next
  # Reject near-duplicate alternate labels. Review is preferable to counting
  # another name for the same industrial site as an additional park.
  point <- st_sfc(st_point(c(b$lon, b$lat)), crs = 4326)
  d <- as.numeric(st_distance(st_transform(point, 3405), st_transform(parks, 3405)))
  if (any(d < 1000 & parks$category == official$category[i])) next
  id <- osm_ids[1]
  if (id %in% vapply(added, function(x) x$id, "")) next
  new <- parks[1, ]
  new$id <- id; new$name_vi <- official$name_vi[i]; new$name_en <- NA_character_
  new$aliases <- b$name_vi; new$category <- official$category[i]
  new$province_code <- b$province_code; new$province_en <- b$province_en
  new$former_province_code <- b$former_province_code
  new$status <- "unknown"; new$area_ha <- NA_real_; new$developer <- NA_character_; new$website <- NA_character_
  new$geometry_type <- "point"; new$location_accuracy <- "locality"
  new$part_count <- length(osm_ids); new$osm_ids <- paste(osm_ids, collapse = "|")
  new$source <- "Invest Vietnam + OpenStreetMap"; new$source_url <- refs[1]
  new$verified_on <- as.Date("2026-09-10"); new$attribute_source <- "official_name_osm_location"
  new$geometry_observed_on <- as.Date(b$verified_on)
  st_geometry(new) <- point
  added[[length(added) + 1L]] <- new
  official$map_id[i] <- id; official$match_method[i] <- "official_name_province_branch_locality"
}
if (length(added)) parks <- rbind(parks, do.call(rbind, added))
map_keys <- aliases(parks)

discovery_rows <- data.frame(
  source_record_id = paste0("kcn-kkt-", discovery$slug), name_vi = discovery$ten,
  category = category(discovery$ten), province_code = vapply(discovery$tinhTen, province_from_text, ""),
  source = "KCN-KKT discovery (unverified)", source_url = discovery$source_url,
  retrieved_on = discovery$retrieved_on, location_text = discovery$diaDiem,
  reported_longitude = NA_real_, reported_latitude = NA_real_, key = park_key(discovery$ten),
  map_id = NA_character_, match_method = "unresolved",
  province_source_url = discovery$source_url, province_match_method = "discovery_reported_unverified",
  stringsAsFactors = FALSE)
for (i in seq_len(nrow(discovery_rows))) {
  h <- lookup(discovery_rows$key[i], discovery_rows$province_code[i], discovery_rows$category[i])
  if (length(h) == 1L && !is.na(discovery_rows$province_code[i])) {
    discovery_rows$map_id[i] <- parks$id[h]
    discovery_rows$match_method[i] <- "discovery_exact_alias_and_province_not_legal_verification"
  } else if (length(h)) discovery_rows$match_method[i] <- "review_ambiguous"
}
sources <- rbind(official, discovery_rows[names(official)])
sources$coordinate_available <- !is.na(sources$map_id)
sources$legal_status <- "not_verified"
sources$review_status <- ifelse(sources$coordinate_available, "linked_to_mapped_site", "needs_identity_or_location_review")
sources$candidate_map_ids <- NA_character_
sources$candidate_match_method <- NA_character_
for (i in which(!sources$coordinate_available)) {
  h <- lookup(sources$key[i], sources$province_code[i], sources$category[i])
  if (length(h)) {
    sources$candidate_map_ids[i] <- paste(parks$id[h], collapse = "|")
    sources$candidate_match_method[i] <- "exact_name_needs_province_or_identity_review"
  }
}
sources$longitude <- sources$latitude <- NA_real_
centers <- st_coordinates(st_transform(suppressWarnings(st_point_on_surface(st_transform(parks, 3405))), 4326))
idx <- match(sources$map_id, parks$id)
sources$longitude <- centers[idx, 1]; sources$latitude <- centers[idx, 2]
sources$coordinate_source_url <- parks$source_url[idx]
sources$reported_coordinate_check <- ifelse(is.na(sources$reported_longitude), "not_reported", "unverified_not_used")
has_reported <- which(is.finite(sources$reported_longitude) & !is.na(sources$province_code))
boundaries <- st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
for (i in has_reported) {
  point <- st_sfc(st_point(c(sources$reported_longitude[i], sources$reported_latitude[i])), crs = 4326)
  h <- st_intersects(point, boundaries)[[1]]
  sources$reported_coordinate_check[i] <- if (sources$province_code[i] %in% boundaries$code[h]) "province_consistent_unverified" else "province_conflict_not_used"
}
stopifnot(nrow(sources) == nrow(feed) + nrow(discovery), !anyDuplicated(sources$source_record_id),
          !anyDuplicated(parks$id), all(st_is_valid(parks)),
          all(is.na(sources$longitude[!sources$coordinate_available])))
saveRDS(parks, "inst/extdata/industrial_parks.rds", compress = "xz")
saveRDS(sources, "inst/extdata/industrial_park_sources.rds", compress = "xz")
write.csv(sources, "data-raw/industrial-park-sources.csv", row.names = FALSE, na = "")
write.csv(sources[!sources$coordinate_available, ], "data-raw/industrial-park-unresolved.csv", row.names = FALSE, na = "")
audit <- as.data.frame(table(source = sources$source, review_status = sources$review_status))
write.csv(audit, "data-raw/industrial-park-source-coverage.csv", row.names = FALSE)
province_coverage <- do.call(rbind, lapply(unique(sources$source), function(s) {
  do.call(rbind, lapply(c(current$code, "unknown"), function(code) {
    rows <- sources$source == s & if (code == "unknown") is.na(sources$province_code) else
      !is.na(sources$province_code) & sources$province_code == code
    data.frame(source = s, province_code = code,
      province_en = if (code == "unknown") "Unknown" else current$name_en[match(code, current$code)],
      source_records = sum(rows), linked_records = sum(sources$coordinate_available[rows]),
      unresolved_records = sum(!sources$coordinate_available[rows]))
  }))
}))
write.csv(province_coverage, "data-raw/industrial-park-source-province-coverage.csv", row.names = FALSE)
write.csv(st_drop_geometry(parks)[c("id", "name_vi", "name_en", "category", "province_en", "status", "area_ha", "geometry_type", "part_count", "source_url")],
          "data-raw/industrial-parks-register.csv", row.names = FALSE)
in_scope <- parks$category %in% c("industrial_park", "export_processing_zone")
baseline <- read.csv("data-raw/industrial-park-baseline.csv")
total <- baseline$value[baseline$metric == "established_parks"]
write.csv(data.frame(metric = c("official_established_baseline", "mapped_register_records",
  "arithmetic_difference_not_verified_missing", "polygon_records", "point_records",
  "hi_tech_park_records", "industrial_cluster_records", "mapped_area_ha", "official_area_ha"),
  value = c(total, sum(in_scope), total - sum(in_scope),
    sum(in_scope & parks$geometry_type == "polygon"), sum(in_scope & parks$geometry_type == "point"),
    sum(parks$category == "hi_tech_park"), sum(parks$category == "industrial_cluster"),
    round(sum(parks$area_ha[in_scope], na.rm = TRUE)), baseline$value[baseline$metric == "established_area_ha"])),
  "data-raw/industrial-parks-audit.csv", row.names = FALSE)
pa <- aggregate(rep(1L, nrow(parks)[1])[in_scope],
  list(province_code = parks$province_code[in_scope], province_en = parks$province_en[in_scope], status = parks$status[in_scope]), sum)
names(pa)[4] <- "mapped_records"
write.csv(pa, "data-raw/industrial-parks-province-audit.csv", row.names = FALSE)
dir.create("output/industrial-parks", recursive = TRUE, showWarnings = FALSE)
st_write(parks, "output/industrial-parks/industrial-parks.geojson", delete_dsn = TRUE, quiet = TRUE)
write.csv(sources, "output/industrial-parks/source-catalogue.csv", row.names = FALSE, na = "")
write.csv(province_coverage, "output/industrial-parks/province-source-coverage.csv", row.names = FALSE)
write.csv(sources[sources$reported_coordinate_check == "province_conflict_not_used", ],
          "output/industrial-parks/coordinate-conflicts.csv", row.names = FALSE, na = "")
print(audit)
cat("Additional corroborated locality points:", length(added), "\n")
print(table(sources$reported_coordinate_check))
