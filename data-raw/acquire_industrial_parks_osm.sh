#!/bin/sh
set -eu

# Bounded acquisition of the Vietnamese industrial-park candidate set from
# OpenStreetMap. Run from the package root. OSM data is ODbL 1.0.
#
# The request is a deliberate superset: every named industrial land use, every
# feature explicitly tagged as an industrial park, and every feature whose name
# carries a Vietnamese or English park/zone/cluster designation. Classification
# and exclusion happen in build_industrial_parks.R, not here, so that the
# saved snapshot can be re-filtered without re-querying the network.
#
# Environment:
#   VNMAP_OVERPASS_ENDPOINTS  space-separated mirrors to try in order
#   VNMAP_SNAPSHOT_DATE       output snapshot date (default: today, UTC)

endpoints=${VNMAP_OVERPASS_ENDPOINTS:-"https://overpass-api.de/api/interpreter https://overpass.private.coffee/api/interpreter https://overpass.kumi.systems/api/interpreter"}
snapshot=${VNMAP_SNAPSHOT_DATE:-$(date -u +%Y-%m-%d)}
out="data-raw/source/osm-industrial-parks-${snapshot}.json"
mkdir -p data-raw/source

query=$(cat <<'QUERY'
[out:json][timeout:600];
area["ISO3166-1"="VN"][admin_level=2]->.vn;
(
  nwr(area.vn)["industrial"="industrial_park"];
  nwr(area.vn)["landuse"="industrial"]["name"];
  nwr(area.vn)["name"~"Khu công nghiệp|Khu chế xuất|Khu công nghệ cao|Cụm công nghiệp|KCN|KCX|CCN |Industrial Park|Industrial Zone|Export Processing",i];
);
out body geom;
QUERY
)

attempt=0
for endpoint in $endpoints; do
  n=0
  while [ "$n" -lt 6 ]; do
    n=$((n + 1))
    attempt=$((attempt + 1))
    echo "attempt ${attempt}: ${endpoint} (try ${n})" >&2
    if curl -sSL -m 900 --data-urlencode "data=${query}" -o "${out}.part" "$endpoint" &&
       head -c 1 "${out}.part" | grep -q '{'; then
      # Overpass reports load-shedding as a 200 response with an HTML body, so
      # the payload itself has to be validated before the snapshot is accepted.
      if command -v jq >/dev/null 2>&1; then
        jq -e '.elements | length > 0' "${out}.part" >/dev/null || { sleep 20; continue; }
      fi
      mv "${out}.part" "$out"
      gzip -9f "$out"
      echo "wrote ${out}.gz" >&2
      shasum -a 256 "${out}.gz"
      exit 0
    fi
    sleep 20
  done
done

echo "all Overpass endpoints failed" >&2
exit 1
