# Build the bundled industrial-park layer from a dated OpenStreetMap snapshot.
#
# Acquire the snapshot with data-raw/acquire_industrial_parks_osm.sh, or set
# VNMAP_OSM_FILE to a saved Overpass JSON response. The snapshot is a
# deliberate superset; every inclusion, exclusion and merge decision is made
# here so that the classification can be revised without re-querying OSM.
#
# Two reviewed CSV files carry human decisions that no rule can make:
#   industrial-parks-include.csv  OSM ids to admit despite an off-pattern name
#   industrial-parks-exclude.csv  OSM ids to reject despite a matching name
# Both are optional; unreviewed borderline features are written to
# industrial-parks-review.csv instead of being guessed at.

if (!requireNamespace("sf", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE) ||
    !requireNamespace("stringi", quietly = TRUE)) {
  stop("Packages 'sf', 'jsonlite' and 'stringi' are required.")
}

snapshot_date <- as.Date(Sys.getenv("VNMAP_SNAPSHOT_DATE", unset = "2026-08-31"))
input <- Sys.getenv("VNMAP_OSM_FILE", unset = "")
if (!nzchar(input)) {
  input <- sprintf("data-raw/source/osm-industrial-parks-%s.json.gz", snapshot_date)
}
if (!file.exists(input)) {
  stop("Snapshot not found: ", input,
       "\nRun data-raw/acquire_industrial_parks_osm.sh first.")
}

# Overpass returns self-intersecting rings for a handful of hand-drawn sites;
# planar geometry lets them be repaired with st_make_valid() before use.
old_s2 <- sf::sf_use_s2(FALSE)
on.exit(sf::sf_use_s2(old_s2), add = TRUE)

con <- if (grepl("\\.gz$", input)) gzfile(input, "rt") else file(input, "rt")
raw <- jsonlite::fromJSON(paste(readLines(con, warn = FALSE), collapse = ""),
                          simplifyVector = FALSE)$elements
close(con)
message("Snapshot elements: ", length(raw))

tag <- function(x, key, default = NA_character_) {
  value <- x$tags[[key]]
  if (is.null(value)) default else as.character(value)
}
normalize <- function(x) {
  x <- tolower(stringi::stri_trans_general(as.character(x), "Latin-ASCII"))
  trimws(gsub(" +", " ", gsub("[^a-z0-9]+", " ", x)))
}

osm_id <- vapply(raw, function(x) paste0("osm_", x$type, "_", x$id), "")
name_vi <- vapply(raw, tag, "", key = "name")
key <- normalize(name_vi)

## Geometry ------------------------------------------------------------------
ring <- function(nodes) {
  xy <- do.call(rbind, lapply(nodes, function(p) c(p$lon, p$lat)))
  if (!all(xy[1, ] == xy[nrow(xy), ])) xy <- rbind(xy, xy[1, ])
  xy
}
make_geometry <- function(x) {
  if (identical(x$type, "way") && length(x$geometry) >= 4L) {
    xy <- ring(x$geometry)
    if (nrow(xy) >= 4L) return(sf::st_polygon(list(xy)))
  }
  if (identical(x$type, "relation") && length(x$members)) {
    outer <- Filter(function(m) identical(m$role, "outer") &&
                      length(m$geometry) >= 4L, x$members)
    if (length(outer)) {
      return(sf::st_multipolygon(lapply(outer, function(m) list(ring(m$geometry)))))
    }
  }
  lon <- if (!is.null(x$lon)) x$lon else mean(c(x$bounds$minlon, x$bounds$maxlon))
  lat <- if (!is.null(x$lat)) x$lat else mean(c(x$bounds$minlat, x$bounds$maxlat))
  sf::st_point(c(lon, lat))
}

## Classification ------------------------------------------------------------
# Vietnamese law separates the designations below, and they are not
# interchangeable: khu che xuat (EPZ) and khu cong nghiep (IP) are both counted
# in the national IP register, while khu cong nghe cao (hi-tech park) and
# cum cong nghiep (industrial cluster, a provincial tier) are not. The
# designation is read from the name because that is how OSM records it; a
# generic landuse=industrial tag says nothing about legal status.
designations <- c(
  export_processing_zone = "^(khu che xuat|kcx)\\b|\\bexport processing (zone|park)$",
  hi_tech_park           = "^(khu cong nghe cao|khu cnc|kcnc)\\b|\\bhi ?tech park$",
  industrial_cluster     = "^(cum cong nghiep|cum cn|ccn)\\b|\\bindustrial cluster$",
  industrial_park        = "^(khu cong nghiep|khu cn|kcn)\\b|\\bindustrial (park|zone)$"
)
category <- rep(NA_character_, length(raw))
for (nm in names(designations)) {
  category[is.na(category) & grepl(designations[[nm]], key)] <- nm
}

# Features that carry a park name only because they sit at, serve, or are
# addressed from one: gates, bus stops, fuel stations, banks, offices.
poi_keys <- c("highway", "public_transport", "barrier", "railway", "aeroway",
              "power", "shop", "man_made", "tourism", "leisure", "craft",
              "emergency", "healthcare")
poi_amenities <- c("fuel", "bank", "atm", "police", "post_office", "restaurant",
                   "cafe", "fast_food", "school", "college", "university",
                   "hospital", "pharmacy", "marketplace", "parking", "toilets",
                   "bus_station", "clinic", "place_of_worship")
is_poi <- vapply(raw, function(x) {
  any(poi_keys %in% names(x$tags)) ||
    (!is.null(x$tags$amenity) && x$tags$amenity %in% poi_amenities)
}, logical(1))
# Tenants and administrative offices named after their host park.
is_tenant <- grepl(paste0("\\b(cong ty|cty|tnhh|nha may|xi nghiep|head office|",
                          "van phong|ban quan ly|bql|nha xuong|kho bai|chi nhanh|",
                          "cua hang|can tin|kho)\\b"), key)

read_decisions <- function(path) {
  if (!file.exists(path)) return(character(0))
  x <- utils::read.csv(path, colClasses = "character")
  unique(trimws(x$id[nzchar(trimws(x$id))]))
}
forced_in <- read_decisions("data-raw/industrial-parks-include.csv")
forced_out <- read_decisions("data-raw/industrial-parks-exclude.csv")
unknown <- setdiff(c(forced_in, forced_out), osm_id)
if (length(unknown)) {
  stop("Reviewed ids absent from the snapshot: ", paste(unknown, collapse = ", "))
}

keep <- (!is.na(category) & !is_poi & !is_tenant & !osm_id %in% forced_out) |
  osm_id %in% forced_in
if (any(is.na(category[osm_id %in% forced_in]))) {
  overrides <- utils::read.csv("data-raw/industrial-parks-include.csv",
                               colClasses = "character")
  category[match(overrides$id, osm_id)] <- overrides$category
}
message("With a park designation or review decision: ", sum(!is.na(category)),
        "; retained after review: ", sum(keep))

## Triage file for large industrial sites that no rule can classify -----------
# Some parks are mapped under a brand name with no legal designation ("VSIP
# III"). They cannot be admitted automatically without also admitting the
# steelworks and power stations that share the same tags and size, so every
# unclassified named industrial polygon above the review threshold is written
# out for a maintainer to rule on in industrial-parks-include.csv.
review_threshold_ha <- 50
undecided <- which(is.na(category) & !keep &
                     vapply(raw, function(x) {
                       identical(tag(x, "landuse", ""), "industrial")
                     }, logical(1)))
if (length(undecided)) {
  review_geometry <- sf::st_sfc(lapply(raw[undecided], make_geometry), crs = 4326)
  review_geometry <- sf::st_make_valid(review_geometry)
  review_area <- suppressWarnings(as.numeric(
    sf::st_area(sf::st_transform(review_geometry, 3405)))) / 10000
  review_area[!sf::st_geometry_type(review_geometry) %in%
                c("POLYGON", "MULTIPOLYGON")] <- NA_real_
  large <- which(!is.na(review_area) & review_area >= review_threshold_ha)
  review <- data.frame(
    id = osm_id[undecided][large],
    name = name_vi[undecided][large],
    area_ha = round(review_area[large]),
    decision = "unreviewed",
    source_url = paste0("https://www.openstreetmap.org/",
                        sub("^osm_([a-z]+)_([0-9]+)$", "\\1/\\2",
                            osm_id[undecided][large])))
  review <- review[order(-review$area_ha), ]
  utils::write.csv(review, "data-raw/industrial-parks-review.csv",
                   row.names = FALSE)
  message("Wrote ", nrow(review), " unclassified industrial sites >= ",
          review_threshold_ha, " ha to data-raw/industrial-parks-review.csv")
}

raw <- raw[keep]
category <- category[keep]
osm_id <- osm_id[keep]
name_vi <- name_vi[keep]
key <- key[keep]

# A park's canonical name drops the designation and the phase or expansion
# suffix, so that "KCN Song Than 1" stays distinct from "KCN Song Than 2" while
# "KCN Dinh Vu" and "KCN Dinh Vu mo rong" collapse into one register entry.
canonical <- key
canonical <- gsub(paste0("^(khu cong nghiep|khu cn|kcn|khu che xuat|kcx|",
                         "khu cong nghe cao|khu cnc|kcnc|cum cong nghiep|",
                         "cum cn|ccn)\\b"), "", canonical)
canonical <- gsub(paste0("\\b(industrial park|industrial zone|",
                         "export processing zone|industrial cluster|",
                         "hi ?tech park)$"), "", canonical)
canonical <- gsub(paste0("\\b(mo rong|mor ong|giai doan [0-9ivx]+|gd [0-9ivx]+|",
                         "phan khu [0-9a-z]+|expansion|phase [0-9]+)\\b"), "",
                  canonical)
canonical <- trimws(gsub(" +", " ", canonical))

# "Khu cong nghiep" on its own names no park and cannot be reconciled with the
# register, so such features are dropped rather than carried as a blank record.
anonymous <- !nzchar(canonical)
if (any(anonymous)) {
  message("Dropping ", sum(anonymous),
          " feature(s) whose name is the designation alone.")
  raw <- raw[!anonymous]
  category <- category[!anonymous]
  osm_id <- osm_id[!anonymous]
  name_vi <- name_vi[!anonymous]
  key <- key[!anonymous]
  canonical <- canonical[!anonymous]
}

geometry <- sf::st_sfc(lapply(raw, make_geometry), crs = 4326)
parts <- sf::st_sf(
  osm_id = osm_id,
  category = category,
  canonical = canonical,
  name_vi = name_vi,
  name_en = vapply(raw, tag, "", key = "name:en"),
  alt_name = vapply(raw, tag, "", key = "alt_name"),
  short_name = vapply(raw, tag, "", key = "short_name"),
  developer = vapply(raw, function(x) {
    op <- tag(x, "operator"); if (!is.na(op)) op else tag(x, "owner")
  }, ""),
  website = vapply(raw, function(x) {
    w <- tag(x, "website"); if (!is.na(w)) w else tag(x, "contact:website")
  }, ""),
  status_tag = vapply(raw, function(x) {
    if (!is.na(tag(x, "construction")) ||
        identical(tag(x, "landuse", ""), "construction")) {
      "under_construction"
    } else if (identical(tag(x, "landuse", ""), "industrial") ||
               identical(tag(x, "industrial", ""), "industrial_park")) {
      "operational"
    } else {
      "unknown"
    }
  }, ""),
  geometry = geometry
)
parts <- sf::st_make_valid(parts)
part_type <- tolower(as.character(sf::st_geometry_type(parts)))
parts$is_polygon <- part_type %in% c("polygon", "multipolygon")

## Provincial attribution ----------------------------------------------------
current <- sf::st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
former <- sf::st_transform(readRDS("inst/extdata/provinces_63.rds"), 4326)
representative <- suppressWarnings(sf::st_point_on_surface(parts))
join_code <- function(boundaries) {
  hits <- sf::st_intersects(representative, boundaries)
  out <- vapply(hits, function(i) if (length(i)) boundaries$code[i[1]] else NA_character_, "")
  # Simplified coastlines drop reclaimed and near-shore sites just offshore.
  missed <- which(is.na(out))
  if (length(missed)) {
    nearest <- sf::st_nearest_feature(representative[missed, ], boundaries)
    distance <- as.numeric(sf::st_distance(
      sf::st_transform(representative[missed, ], 3405),
      sf::st_transform(boundaries[nearest, ], 3405), by_element = TRUE))
    out[missed] <- ifelse(distance <= 5000, boundaries$code[nearest], NA_character_)
  }
  out
}
parts$province_code <- join_code(current)
parts$former_province_code <- join_code(former)

# The two provincial layers come from different upstream sources, so their
# boundaries disagree by a few hundred metres. The current, commune-derived
# assignment governs: a park's former province must be one of the units its
# current province absorbed in 2025, and the nearest such unit is chosen when
# the raw join lands outside that set.
membership <- utils::read.csv("data-raw/provinces_34.csv", colClasses = "character")
members <- strsplit(membership$members, "+", fixed = TRUE)
names(members) <- membership$code
allowed <- members[parts$province_code]
mismatch <- which(!mapply(function(code, ok) code %in% ok,
                          parts$former_province_code, allowed))
for (i in mismatch) {
  candidates <- which(former$code %in% allowed[[i]])
  if (!length(candidates)) next
  distance <- as.numeric(sf::st_distance(
    sf::st_transform(representative[i, ], 3405),
    sf::st_transform(former[candidates, ], 3405)))
  parts$former_province_code[i] <- former$code[candidates[which.min(distance)]]
}
if (length(mismatch)) {
  message("Reassigned ", length(mismatch),
          " feature(s) whose former province conflicted with the current one.")
}

offshore <- is.na(parts$province_code)
if (any(offshore)) {
  message("Dropping ", sum(offshore), " feature(s) outside the province layer: ",
          paste(parts$name_vi[offshore], collapse = "; "))
  parts <- parts[!offshore, ]
}

## Merge the parts of a single park ------------------------------------------
# One park is frequently mapped as several polygons (phases, a road-split
# site) plus a label node. Components are merged when they share a province,
# a designation and a canonical name, and lie within a kilometre of each
# other; distant same-name sites stay separate records.
projected <- sf::st_transform(parts, 3405)
group <- paste(parts$province_code, parts$category, parts$canonical, sep = "|")
parts$cluster <- NA_character_
for (g in unique(group)) {
  idx <- which(group == g)
  if (length(idx) == 1L) {
    parts$cluster[idx] <- paste0(g, "|1")
    next
  }
  near <- sf::st_is_within_distance(projected[idx, ], dist = 1000)
  label <- rep(NA_integer_, length(idx))
  next_label <- 0L
  for (i in seq_along(idx)) {
    if (!is.na(label[i])) next
    next_label <- next_label + 1L
    queue <- i
    while (length(queue)) {
      j <- queue[1]; queue <- queue[-1]
      if (!is.na(label[j])) next
      label[j] <- next_label
      queue <- c(queue, setdiff(near[[j]], which(!is.na(label))))
    }
  }
  parts$cluster[idx] <- paste0(g, "|", label)
}

pick <- function(x) {
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) NA_character_ else x[[1]]
}
clusters <- unique(parts$cluster)
records <- lapply(clusters, function(cl) {
  part <- parts[parts$cluster == cl, ]
  polygons <- part[part$is_polygon, ]
  if (nrow(polygons)) {
    # Union in the projected CRS: adjacent phases of one park share an edge,
    # and a planar union of longitude/latitude rings is not well defined.
    geom <- sf::st_transform(
      sf::st_union(sf::st_geometry(sf::st_transform(polygons, 3405))), 4326)
    geometry_type <- "polygon"
    named <- polygons
  } else {
    geom <- sf::st_geometry(part)[1]
    geometry_type <- "point"
    named <- part
  }
  # A merged record is named for the park, not for one of its phases, so the
  # base name wins over "... mo rong" / "... giai doan 2"; among equals the
  # longest name is the most complete one and the rest become aliases.
  phase <- grepl(paste0("\\b(mo rong|giai doan|gd [0-9ivx]|phan khu|",
                        "expansion|phase [0-9])\\b"), normalize(named$name_vi))
  rank <- order(phase, -nchar(named$name_vi))
  primary <- named[rank[1], ]
  aliases <- unique(c(part$name_vi, part$name_en, part$alt_name, part$short_name))
  aliases <- aliases[!is.na(aliases) & nzchar(aliases) & aliases != primary$name_vi]
  status <- if (any(part$status_tag == "operational")) {
    "operational"
  } else if (any(part$status_tag == "under_construction")) {
    "under_construction"
  } else {
    "unknown"
  }
  sf::st_sf(
    id = primary$osm_id,
    canonical = primary$canonical,
    name_vi = primary$name_vi,
    name_en = pick(named$name_en),
    aliases = if (length(aliases)) paste(aliases, collapse = "|") else NA_character_,
    category = primary$category,
    province_code = primary$province_code,
    former_province_code = primary$former_province_code,
    status = status,
    developer = pick(named$developer),
    website = pick(named$website),
    geometry_type = geometry_type,
    location_accuracy = if (geometry_type == "polygon") "site" else "locality",
    part_count = nrow(part),
    osm_ids = paste(sort(part$osm_id), collapse = "|"),
    geometry = geom
  )
})
parks <- do.call(rbind, records)
sf::st_crs(parks) <- 4326
parks <- sf::st_make_valid(parks)

# Streets and gates inside a park are frequently mapped as nodes named after
# it ("KCN Tam Phuoc Duong So 1"). Such a node is dropped when it falls inside
# a mapped park whose canonical name is a prefix of its own, or the reverse -
# an unnumbered node inside its own numbered site. A contained node with an
# unrelated name is a neighbouring park whose boundary is drawn imprecisely,
# and is kept.
prefix_of <- function(a, b) {
  a == b | startsWith(a, paste0(b, " ")) | startsWith(b, paste0(a, " "))
}
inside <- rep(FALSE, nrow(parks))
container <- rep(NA_character_, nrow(parks))
for (cat_name in unique(parks$category)) {
  in_cat <- parks$category == cat_name
  areas <- which(in_cat & parks$geometry_type == "polygon")
  points <- which(in_cat & parks$geometry_type == "point")
  if (!length(areas) || !length(points)) next
  hits <- sf::st_within(parks[points, ], parks[areas, ])
  for (i in seq_along(points)) {
    hit <- hits[[i]]
    if (!length(hit)) next
    same <- hit[prefix_of(parks$canonical[points[i]], parks$canonical[areas][hit])]
    if (!length(same)) next
    inside[points[i]] <- TRUE
    container[points[i]] <- parks$name_vi[areas][same[1]]
  }
}
if (any(inside)) {
  message("Dropping ", sum(inside),
          " node(s) naming a street or gate inside a mapped park.")
  if (nzchar(Sys.getenv("VNMAP_TRACE_DROPS"))) {
    print(data.frame(point = parks$name_vi[inside],
                     inside_of = container[inside]))
  }
  parks <- parks[!inside, ]
}

info <- readRDS("inst/extdata/provinces_info.rds")
parks$province_en <- info$name_en[match(parks$province_code, info$code)]
parks$area_ha <- NA_real_
is_polygon <- parks$geometry_type == "polygon"
parks$area_ha[is_polygon] <- as.numeric(
  sf::st_area(sf::st_transform(parks[is_polygon, ], 3405))) / 10000

parks$source <- "OpenStreetMap"
parks$source_url <- paste0(
  "https://www.openstreetmap.org/",
  sub("^osm_([a-z]+)_([0-9]+)$", "\\1/\\2", parks$id))
parks$verified_on <- snapshot_date
parks$attribute_source <- "osm"

parks <- parks[order(parks$province_code, parks$category, parks$name_vi), ]
parks <- parks[c(
  "id", "name_vi", "name_en", "aliases", "category", "province_code",
  "province_en", "former_province_code", "status", "area_ha", "developer",
  "website", "geometry_type", "location_accuracy", "part_count", "osm_ids",
  "source", "source_url", "verified_on", "attribute_source", "geometry"
)]
row.names(parks) <- NULL

stopifnot(!anyNA(parks$province_code), !any(duplicated(parks$id)),
          all(sf::st_is_valid(parks)))

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(parks, "inst/extdata/industrial_parks.rds", compress = "xz")

## Audits --------------------------------------------------------------------
baseline <- utils::read.csv("data-raw/industrial-park-baseline.csv",
                            colClasses = c(value = "integer"))
established <- baseline$value[baseline$metric == "established_parks"]
in_scope <- parks[parks$category %in%
                    c("industrial_park", "export_processing_zone"), ]
audit <- data.frame(
  metric = c("official_established_baseline", "mapped_register_records",
             "unmapped_against_baseline", "polygon_records", "point_records",
             "hi_tech_park_records", "industrial_cluster_records",
             "mapped_area_ha", "official_area_ha"),
  value = c(
    established, nrow(in_scope),
    max(established - nrow(in_scope), 0L),
    sum(in_scope$geometry_type == "polygon"),
    sum(in_scope$geometry_type == "point"),
    sum(parks$category == "hi_tech_park"),
    sum(parks$category == "industrial_cluster"),
    round(sum(in_scope$area_ha, na.rm = TRUE)),
    baseline$value[baseline$metric == "established_area_ha"])
)
utils::write.csv(audit, "data-raw/industrial-parks-audit.csv", row.names = FALSE)

province_audit <- as.data.frame(table(
  province_code = in_scope$province_code,
  status = in_scope$status), stringsAsFactors = FALSE)
province_audit <- province_audit[province_audit$Freq > 0, ]
province_audit$province_en <- info$name_en[match(province_audit$province_code,
                                                 info$code)]
names(province_audit)[names(province_audit) == "Freq"] <- "mapped_records"
utils::write.csv(province_audit[c("province_code", "province_en", "status",
                                  "mapped_records")],
                 "data-raw/industrial-parks-province-audit.csv", row.names = FALSE)

utils::write.csv(
  sf::st_drop_geometry(parks)[c("id", "name_vi", "name_en", "category",
                                "province_en", "status", "area_ha",
                                "geometry_type", "part_count", "source_url")],
  "data-raw/industrial-parks-register.csv", row.names = FALSE)

message("Built ", nrow(parks), " park records (",
        nrow(in_scope), " in the KCN/KCX register scope); baseline gap: ",
        established - nrow(in_scope), ".")
