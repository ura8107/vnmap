# Build the redistributable transport-facility and trunk-network snapshot.
#
# Facility coordinates come from a fixed OpenStreetMap/Overpass response under
# ODbL 1.0. Categories remain deliberately neutral: OSM `industrial=port` is
# not evidence that a facility is a seaport, and `aeroway=aerodrome` is not
# evidence of scheduled commercial service. Network lines come from the
# checksum-pinned Geofabrik Viet Nam extract documented in data-raw/README.md.

library(sf)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.")

facility_file <- "data-raw/source/osm-transport-facilities-2026-08-11.json"
expected_md5 <- "41f7cd7aaf2d53e7352a9e751014bc57"
stopifnot(file.exists(facility_file), unname(tools::md5sum(facility_file)) == expected_md5)
payload <- jsonlite::fromJSON(facility_file, simplifyVector = FALSE)
raw <- payload$elements
facility_base_timestamp <- payload$osm3s$timestamp_osm_base
facility_retrieved_on <- as.Date("2026-08-11")

tag <- function(x, key) {
  value <- x$tags[[key]]
  if (is.null(value)) NA_character_ else as.character(value)
}
key <- function(x) gsub("[^a-z0-9]", "", tolower(stringi::stri_trans_general(x, "Latin-ASCII")))
collapse_unique <- function(x) paste(sort(unique(x[!is.na(x) & nzchar(x)])), collapse = "|")

classify_type <- function(x) {
  if (identical(tag(x, "aeroway"), "aerodrome")) return("aerodrome")
  if (identical(tag(x, "industrial"), "port")) return("port")
  if (identical(tag(x, "barrier"), "border_control") ||
      identical(tag(x, "amenity"), "customs") ||
      identical(tag(x, "amenity"), "border_control")) return("border_control")
  NA_character_
}

classify_facility <- function(type, name, x) {
  k <- key(name)
  if (type == "port") {
    if (grepl("khucongnghiep|cuakhau", k)) return(c("exclude", "not_a_port"))
    if (grepl("cangca|haisan", k)) return(c("include", "fishing_port"))
    if (grepl("(^|[^a-z])icd([^a-z]|$)|dry port", tolower(name), perl = TRUE))
      return(c("include", "dry_port"))
    return(c("include", "industrial_port_unspecified"))
  }
  if (type == "aerodrome") {
    military <- collapse_unique(c(tag(x, "military"), tag(x, "aerodrome:type")))
    if (grepl("military|air_base|airfield", military, ignore.case = TRUE) ||
        grepl("air base|khong quan", stringi::stri_trans_general(name, "Latin-ASCII"), ignore.case = TRUE))
      return(c("include", "military_aerodrome"))
    if (identical(tag(x, "aerodrome:type"), "public"))
      return(c("include", "public_aerodrome"))
    return(c("include", "aerodrome_unspecified"))
  }
  role <- if (grepl("donbienphong", k)) "border_post" else
    if (grepl("tramkiemsoat", k)) "control_station" else
      if (grepl("trungtamquanly", k)) "management_office" else "crossing"
  c("include", role)
}

classify_status <- function(x) {
  candidates <- c(construction = tag(x, "construction"), proposed = tag(x, "proposed"),
                  disused = tag(x, "disused"), abandoned = tag(x, "abandoned"),
                  operational_status = tag(x, "operational_status"))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  if (!length(candidates)) return(c(status = "unknown", source = "none"))
  text <- paste(candidates, collapse = "|")
  source <- paste(paste(names(candidates), candidates, sep = "="), collapse = "|")
  status <- if ("abandoned" %in% names(candidates) || grepl("abandoned", text, TRUE)) "abandoned" else
    if ("disused" %in% names(candidates) || grepl("disused", text, TRUE)) "disused" else
      if ("construction" %in% names(candidates) || grepl("construction", text, TRUE)) "under_construction" else
        if ("proposed" %in% names(candidates) || grepl("planned|proposed", text, TRUE)) "planned" else
          if (grepl("operational|open", text, ignore.case = TRUE)) "operational" else "unknown"
  c(status = status, source = source)
}

candidate_rows <- list()
audit_rows <- list()
for (x in raw) {
  type <- classify_type(x)
  if (is.na(type)) next
  osm_id <- paste0("osm-", x$type, "-", x$id)
  name <- tag(x, "name")
  if (is.na(name) || !nzchar(trimws(name))) {
    audit_rows[[length(audit_rows) + 1L]] <- data.frame(
      source_id = osm_id, infrastructure_type = type, name = NA_character_,
      decision = "excluded", reason = "missing_name", entity_id = NA_character_)
    next
  }
  decision <- classify_facility(type, name, x)
  if (decision[1] == "exclude") {
    audit_rows[[length(audit_rows) + 1L]] <- data.frame(
      source_id = osm_id, infrastructure_type = type, name = name,
      decision = "excluded", reason = decision[2], entity_id = NA_character_)
    next
  }
  method <- if (!is.null(x$lon) && !is.null(x$lat)) "osm_node" else
    if (!is.null(x$center$lon) && !is.null(x$center$lat)) "osm_center" else
      if (!is.null(x$bounds)) "bounds_midpoint" else NA_character_
  lon <- if (method == "osm_node") x$lon else if (method == "osm_center") x$center$lon else
    if (method == "bounds_midpoint") mean(c(x$bounds$minlon, x$bounds$maxlon)) else NA_real_
  lat <- if (method == "osm_node") x$lat else if (method == "osm_center") x$center$lat else
    if (method == "bounds_midpoint") mean(c(x$bounds$minlat, x$bounds$maxlat)) else NA_real_
  if (is.na(lon) || is.na(lat)) {
    audit_rows[[length(audit_rows) + 1L]] <- data.frame(
      source_id = osm_id, infrastructure_type = type, name = name,
      decision = "excluded", reason = "missing_coordinate", entity_id = NA_character_)
    next
  }
  lifecycle <- classify_status(x)
  service_type <- if (type == "aerodrome" &&
    (!is.na(tag(x, "iata")) || grepl("quoc te|international",
      stringi::stri_trans_general(name, "Latin-ASCII"), ignore.case = TRUE)))
    "commercial_service_candidate" else if (type == "aerodrome")
      "service_not_established" else if (type == "port") decision[2] else
        "not_applicable"
  candidate_rows[[length(candidate_rows) + 1L]] <- data.frame(
    source_id = osm_id, name_vi = name,
    name_en = ifelse(is.na(tag(x, "name:en")), name, tag(x, "name:en")),
    infrastructure_type = type, infrastructure_class = decision[2],
    service_type = service_type,
    facility_role = if (type == "border_control") decision[2] else "facility",
    status = lifecycle[["status"]], status_source = lifecycle[["source"]],
    osm_type = x$type, osm_id = as.character(x$id), osm_ref = tag(x, "ref"),
    iata = tag(x, "iata"), icao = tag(x, "icao"), access = tag(x, "access"),
    military = tag(x, "military"), aerodrome_type = tag(x, "aerodrome:type"),
    source_geometry_method = method, lon = lon, lat = lat,
    source_url = paste0("https://www.openstreetmap.org/", x$type, "/", x$id),
    stringsAsFactors = FALSE
  )
}
rows <- do.call(rbind, candidate_rows)

# First collapse duplicate OSM representations with the same normalized name.
priority <- match(rows$osm_type, c("node", "way", "relation"))
rows <- rows[order(rows$infrastructure_type, key(rows$name_vi), -priority, rows$source_id), ]
same_name <- paste(rows$infrastructure_type, key(rows$name_vi))
name_groups <- split(seq_len(nrow(rows)), same_name)

entities <- lapply(name_groups, function(ix) {
  primary <- ix[1L]
  row <- rows[primary, , drop = FALSE]
  row$aliases <- collapse_unique(c(rows$name_vi[ix], rows$name_en[ix]))
  row$source_ids <- collapse_unique(rows$source_id[ix])
  row$facility_roles <- collapse_unique(rows$facility_role[ix])
  for (j in ix[-1L]) audit_rows[[length(audit_rows) + 1L]] <<- data.frame(
    source_id = rows$source_id[j], infrastructure_type = rows$infrastructure_type[j],
    name = rows$name_vi[j], decision = "duplicate", reason = "same_normalized_name",
    entity_id = rows$source_id[primary])
  row
})
entities <- do.call(rbind, entities)
entities <- st_as_sf(entities, coords = c("lon", "lat"), crs = 4326, remove = TRUE)

# Facility-level reconciliation: aerodrome aliases within 250 m and border
# components within 150 m become one entity. Ports are not spatially collapsed
# because distinct terminals commonly share a waterfront.
cluster_near <- function(x, distance_m) {
  if (nrow(x) < 2L) return(seq_len(nrow(x)))
  adj <- st_is_within_distance(x, x, dist = distance_m)
  group <- integer(nrow(x)); next_group <- 0L
  for (i in seq_len(nrow(x))) {
    linked <- unique(c(i, adj[[i]]))
    existing <- unique(group[linked][group[linked] > 0L])
    if (!length(existing)) { next_group <- next_group + 1L; group[linked] <- next_group }
    else group[linked] <- min(existing)
  }
  group
}
final_entities <- list()
for (type in c("aerodrome", "port", "border_control")) {
  z <- entities[entities$infrastructure_type == type, ]
  group <- if (type == "aerodrome") cluster_near(z, 250) else
    if (type == "border_control") cluster_near(z, 150) else seq_len(nrow(z))
  for (ix in split(seq_len(nrow(z)), group)) {
    # Prefer the actual crossing, then the most descriptive name, then OSM area.
    crossing <- z$facility_role[ix] == "crossing"
    score <- nchar(z$name_vi[ix]) + 1000L * crossing +
      10L * match(z$osm_type[ix], c("node", "way", "relation"))
    primary <- ix[which.max(score)]
    row <- z[primary, ]
    row$aliases <- collapse_unique(c(z$aliases[ix], z$name_vi[ix], z$name_en[ix]))
    row$source_ids <- collapse_unique(c(z$source_ids[ix], z$source_id[ix]))
    row$facility_roles <- collapse_unique(c(z$facility_roles[ix], z$facility_role[ix]))
    row$entity_id <- row$source_id
    for (j in setdiff(ix, primary)) audit_rows[[length(audit_rows) + 1L]] <- data.frame(
      source_id = z$source_id[j], infrastructure_type = type, name = z$name_vi[j],
      decision = "duplicate", reason = "spatially_same_entity", entity_id = row$entity_id)
    final_entities[[length(final_entities) + 1L]] <- row
  }
}
infra <- do.call(rbind, final_entities)
country <- st_union(st_geometry(readRDS("inst/extdata/provinces.rds")))
inside <- lengths(st_intersects(st_geometry(infra), country)) > 0L
# Coastal-port centres and border controls may legitimately fall just outside a
# generalized land polygon. Retain points within 15 km, but expose that spatial
# relationship instead of pretending they are strictly inside the boundary.
country_3405 <- st_make_valid(st_transform(st_sf(geometry = country), 3405))
distance_to_country_m <- as.numeric(st_distance(
  st_transform(infra, 3405), country_3405
))
near_country <- distance_to_country_m <= 15000
infra$country_relation <- ifelse(inside, "inside_generalized_boundary",
                                  "within_15km_of_generalized_boundary")
infra$distance_to_country_m <- distance_to_country_m
for (i in which(!near_country)) audit_rows[[length(audit_rows) + 1L]] <- data.frame(
  source_id = infra$source_id[i], infrastructure_type = infra$infrastructure_type[i],
  name = infra$name_vi[i], decision = "excluded", reason = "more_than_15km_from_country_geometry",
  entity_id = infra$entity_id[i])
infra <- infra[near_country, ]
for (i in seq_len(nrow(infra))) audit_rows[[length(audit_rows) + 1L]] <- data.frame(
  source_id = infra$source_id[i], infrastructure_type = infra$infrastructure_type[i],
  name = infra$name_vi[i], decision = "included", reason = "retained_entity",
  entity_id = infra$entity_id[i])

prov <- readRDS("inst/extdata/provinces.rds")
idx <- st_nearest_feature(infra, prov)
infra$province_code <- prov$code[idx]
infra$province_en <- prov$name_en[idx]
infra$id <- infra$entity_id
infra$geometry_type <- "point"
infra$location_accuracy <- infra$source_geometry_method
infra$valid_from <- as.Date(NA); infra$valid_to <- as.Date(NA)
infra$snapshot_date <- as.Date(substr(facility_base_timestamp, 1L, 10L))
infra$observed_on <- facility_retrieved_on
infra$source_authority <- "community"
infra$verification_status <- "not_verified_against_official_register"
infra$source_snapshot <- paste("OSM base", facility_base_timestamp,
                               "retrieved", facility_retrieved_on)

# Nationwide line extract from the checksum-pinned Geofabrik Vietnam PBF.
network_file <- "data-raw/source/osm-trunk-lines-2026-08-10.rds"
network_md5 <- "c21c8f1a686868de4a630514bb2ff036"
stopifnot(file.exists(network_file),
          unname(tools::md5sum(network_file)) == network_md5)
net <- readRDS(network_file)
st_geometry(net) <- "geometry"
other <- ifelse(is.na(net$other_tags), "", net$other_tags)
other_value <- function(z, field) {
  pattern <- paste0('.*"', field, '"=>"([^"]+)".*')
  value <- sub(pattern, "\\1", z)
  value[value == z] <- NA_character_
  value
}
ref <- other_value(other, "ref")
railway_service <- other_value(other, "service")
railway_usage <- other_value(other, "usage")
is_rail <- net$railway %in% c("rail", "construction", "proposed", "disused", "abandoned")
is_express <- net$highway %in% c("motorway", "motorway_link") | grepl("^CT", ref)
is_national <- grepl("^QL", ref)
is_rail[is.na(is_rail)] <- FALSE; is_express[is.na(is_express)] <- FALSE; is_national[is.na(is_national)] <- FALSE
keep <- is_rail | is_express | is_national
net <- net[keep, ]; ref <- ref[keep]; is_rail <- is_rail[keep]; is_express <- is_express[keep]
net$infrastructure_type <- ifelse(is_rail, "railway", ifelse(is_express, "expressway", "national_highway"))
has_key <- function(z, k) grepl(paste0('"', k, '"=>'), z, fixed = TRUE)
o <- ifelse(is.na(net$other_tags), "", net$other_tags)
net$status <- ifelse(net$railway %in% "abandoned" | has_key(o, "abandoned"), "abandoned",
  ifelse(net$railway %in% "disused" | has_key(o, "disused"), "disused",
  ifelse(net$highway %in% "construction" | net$railway %in% "construction" | has_key(o, "construction"), "under_construction",
  ifelse(net$highway %in% "proposed" | net$railway %in% "proposed" | has_key(o, "proposed"), "planned", "unknown"))))
net$status_source <- ifelse(net$status == "unknown", "none", "OSM lifecycle key")
net$id <- paste0("osm-way-", net$osm_id); net$entity_id <- NA_character_
net$name_vi <- ifelse(is.na(net$name), ifelse(is.na(ref), net$id, ref), net$name)
net$name_en <- NA_character_; net$aliases <- NA_character_; net$source_ids <- NA_character_
net$facility_roles <- "network_segment"
net$facility_role <- "network_segment"
net$railway_service <- railway_service[keep]
net$railway_usage <- railway_usage[keep]
net$osm_ref <- ref
rail_class <- ifelse(!is.na(net$railway_service),
  paste0("rail_", gsub("[^a-z0-9]+", "_", tolower(net$railway_service))),
  ifelse(net$railway_usage %in% "main", "main_line",
  ifelse(net$railway_usage %in% "branch", "branch_line",
  ifelse(net$railway_usage %in% "industrial", "industrial_line",
  ifelse(net$railway_usage %in% "military", "military_line",
  ifelse(net$railway_usage %in% "tourism", "tourism_line", "rail_line_unspecified"))))))
net$infrastructure_class <- ifelse(net$infrastructure_type == "railway", rail_class, "trunk")
net$service_type <- ifelse(net$infrastructure_type == "railway",
  ifelse(!is.na(net$railway_service), paste0("service=", net$railway_service),
         ifelse(!is.na(net$railway_usage), paste0("usage=", net$railway_usage),
                "service_and_usage_not_tagged")), "not_applicable")
net$source_url <- paste0("https://www.openstreetmap.org/way/", net$osm_id)
# Generalize before clipping so simplification cannot subsequently push a line
# back outside the documented national polygon.
net <- st_transform(net, 3405)
st_geometry(net) <- st_simplify(st_geometry(net), dTolerance = 100,
                                preserveTopology = TRUE)
# Restrict networks to the documented national polygon. Unlike facility points,
# lines have no coastal/border tolerance: a retained transport segment must
# actually intersect Viet Nam, and crossing ways are clipped at the boundary.
original_distance_m <- as.numeric(st_distance(net, country_3405))
original_intersects <- lengths(st_intersects(net, country_3405)) > 0L
original_within <- lengths(st_within(net, country_3405)) > 0L
network_excluded <- st_drop_geometry(net[!original_intersects, c(
  "id", "infrastructure_type", "infrastructure_class", "status",
  "railway_service", "railway_usage", "source_url"
)])
network_excluded$decision <- "excluded"
network_excluded$reason <- "does_not_intersect_generalized_vietnam_boundary"
net <- net[original_intersects, ]
original_distance_m <- original_distance_m[original_intersects]
original_within <- original_within[original_intersects]
net$country_relation <- ifelse(original_within, "within_generalized_boundary",
                                "intersects_generalized_boundary")
net$distance_to_country_m <- original_distance_m
within_net <- net[original_within, ]
crossing_net <- suppressWarnings(st_intersection(
  net[!original_within, ], country_3405
))
net <- rbind(within_net, crossing_net)
net <- net[order(net$id), ]
# GEOS may report sub-millimetre boundary slivers after validity repair even
# though st_intersection() produced the geometry.  Assert the policy-relevant
# condition directly: every retained segment touches the country and has zero
# computed separation from it.
stopifnot(all(lengths(st_intersects(net, country_3405)) > 0L),
          all(as.numeric(st_distance(net, country_3405)) <= 1e-6))
net <- st_transform(net, 4326)
net$geometry_type <- "line"
net$location_accuracy <- "osm_way_generalized_100m"
net$source_geometry_method <- "osm_way_generalized_100m"
net$valid_from <- as.Date(NA); net$valid_to <- as.Date(NA)
net$snapshot_date <- as.Date("2026-08-10"); net$observed_on <- as.Date("2026-08-10")
net$source_authority <- "community"; net$verification_status <- "not_verified_against_official_register"
net$source_snapshot <- "Geofabrik vietnam-260810.osm.pbf; MD5 8d79d8ca13e45a733d15504b9a9c84dc"
net$osm_type <- "way"
for (nm in c("iata", "icao", "access", "military", "aerodrome_type")) net[[nm]] <- NA_character_
province_hits <- st_intersects(st_geometry(net), st_geometry(st_transform(prov, 4326)))
net$province_codes <- vapply(province_hits, function(i) {
  collapse_unique(prov$code[i])
}, character(1))
net$province_codes[!nzchar(net$province_codes)] <- NA_character_
net$province_assignment_method <- ifelse(is.na(net$province_codes),
  "no_polygon_intersection", "polygon_intersection")
# Lines may span multiple provinces; a scalar ownership code would be false.
net$province_code <- NA_character_; net$province_en <- NA_character_

common <- c("id", "entity_id", "name_vi", "name_en", "aliases", "source_ids",
  "infrastructure_type", "infrastructure_class", "service_type", "facility_role", "facility_roles",
  "status", "status_source", "province_code", "province_en", "geometry_type",
  "location_accuracy", "source_geometry_method", "osm_type", "osm_ref", "iata", "icao",
  "access", "military", "aerodrome_type", "valid_from", "valid_to", "snapshot_date",
  "observed_on", "source_authority", "verification_status", "source_snapshot",
  "country_relation", "distance_to_country_m", "province_codes",
  "province_assignment_method", "railway_service", "railway_usage",
  "source_url", "geometry")
infra$province_codes <- infra$province_code
infra$province_assignment_method <- "nearest_parent_for_point"
infra$railway_service <- NA_character_
infra$railway_usage <- NA_character_
infra <- infra[common]
net <- net[common]
infra <- rbind(infra, net)
infra <- infra[order(infra$infrastructure_type, infra$id), ]
stopifnot(!anyDuplicated(infra$id), !any(st_is_empty(infra)), all(st_is_valid(infra)))

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(infra, "inst/extdata/infrastructure.rds", compress = "xz", version = 3)
audit <- do.call(rbind, audit_rows)
audit <- audit[order(audit$infrastructure_type, audit$source_id, audit$decision), ]
stopifnot(!anyDuplicated(audit$source_id),
          all(audit$decision %in% c("included", "duplicate", "excluded")))
utils::write.csv(audit, "data-raw/infrastructure-audit.csv", row.names = FALSE)
network_audit <- st_drop_geometry(net[c(
  "id", "infrastructure_type", "infrastructure_class", "status",
  "railway_service", "railway_usage", "country_relation",
  "distance_to_country_m", "province_codes", "province_assignment_method",
  "source_url"
)])
network_audit$decision <- "included"
network_audit$reason <- "intersects_generalized_vietnam_boundary"
network_excluded$country_relation <- "outside_generalized_boundary"
network_excluded$distance_to_country_m <- NA_real_
network_excluded$province_codes <- NA_character_
network_excluded$province_assignment_method <- "not_applicable_excluded"
network_audit <- rbind(network_audit, network_excluded[names(network_audit)])
network_audit <- network_audit[order(network_audit$infrastructure_type,
                                     network_audit$id), ]
utils::write.csv(network_audit, "data-raw/infrastructure-network-audit.csv",
                 row.names = FALSE)
message("Wrote ", nrow(infra), " infrastructure features; facility audit has ",
        nrow(audit), " source-feature decisions; network audit has ",
        sum(network_audit$decision == "included"), " retained and ",
        sum(network_audit$decision == "excluded"), " excluded ways.")
