#!/bin/sh
set -eu
url=https://download.geofabrik.de/asia/vietnam-260810.osm.pbf
out=${VNMAP_OSM_PBF:-data-raw/source/vietnam-260810.osm.pbf}
expected=8d79d8ca13e45a733d15504b9a9c84dc
curl -fL --retry 5 --retry-all-errors -o "$out" "$url"
actual=$(md5 -q "$out" 2>/dev/null || md5sum "$out" | awk '{print $1}')
test "$actual" = "$expected"
