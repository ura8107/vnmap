#!/bin/sh
set -eu

# Exact bounded acquisition used for the 2026-08-11 infrastructure snapshot.
# Run from the package root. OSM data is ODbL 1.0.
endpoint=${VNMAP_OVERPASS_ENDPOINT:-https://overpass-api.de/api/interpreter}
tile_dir=data-raw/source/osm-network-tiles-2026-08-11
mkdir -p "$tile_dir"

# Facility request. `out tags bb` preserves exact node coordinates and bounding
# boxes for ways/relations; the build records which method supplied each point.
facility_query='[out:json][timeout:240];area["ISO3166-1"="VN"][admin_level=2]->.vn;(nwr["aeroway"="aerodrome"](area.vn);nwr["industrial"="port"](area.vn);nwr["barrier"="border_control"](area.vn);nwr["amenity"~"^(customs|border_control)$"](area.vn););out tags bb;'
curl -L --fail --retry 5 --retry-delay 2 --data-urlencode "data=${facility_query}" \
  -o data-raw/source/osm-transport-facilities-current.json "$endpoint"

for south in 8 12 16 20; do
  north=$((south + 4))
  for west in 102 104 106 108; do
    east=$((west + 2))
    tile="${south}_${west}_${north}_${east}"
    query="[out:json][timeout:240];(way[\"highway\"~\"^(motorway|trunk)$\"](${south},${west},${north},${east});way[\"highway\"=\"construction\"](${south},${west},${north},${east});way[\"highway\"=\"proposed\"](${south},${west},${north},${east});way[\"railway\"~\"^(rail|construction|proposed)$\"](${south},${west},${north},${east}););out tags geom;"
    curl -L --fail --retry 5 --retry-delay 2 --data-urlencode "data=${query}" \
      -o "${tile_dir}/${tile}.json" "$endpoint"
  done
done

# Deduplicate ways crossing tile boundaries and sort for a stable snapshot.
jq -s '{version: 0.6, generator: "vnmap tiled Overpass acquisition", elements: ([.[].elements[]] | unique_by([.type,.id]) | sort_by(.type,.id))}' \
  "$tile_dir"/*.json > data-raw/source/osm-trunk-networks-2026-08-11.json
