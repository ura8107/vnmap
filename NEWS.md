# vnmap (development version)

## Industrial parks

* `industrial_parks()` gains a `category` argument separating khu cong nghiep,
  khu che xuat, khu cong nghe cao and cum cong nghiep. The default is the
  national register scope - industrial parks and export processing zones - so
  provincial-tier industrial clusters no longer sit unlabelled alongside them.

  `category` sits after `province` in the signature, so calls that passed
  `status` positionally as the second argument must now name it. Filtering by
  the default also removes the industrial clusters that previous versions
  returned unlabelled.

* `industrial_parks()` gains an `attributes` argument that overlays
  user-supplied basic information onto the bundled layer. Rows matching an
  existing `id` update that park; rows with a new `id` add a park from a
  supplied name, province and coordinate, which is how a park the snapshot does
  not carry gets onto a map. Changed and added rows are marked
  `attribute_source = "user"`.

* Added `industrial_parks_template()`, which writes the columns a user may fill
  in, and `write_industrial_parks()`, which exports a layer as CSV, GeoJSON or
  GeoPackage. CSV output carries `longitude` and `latitude` and feeds straight
  back into `attributes`.

* Rebuilt the industrial-park layer from a 31 August 2026 OpenStreetMap
  snapshot, acquired by the new `data-raw/acquire_industrial_parks_osm.sh`.
  The build now assembles relation multipolygons, merges the separately mapped
  phases and expansions of one park into a single record with `part_count` and
  `osm_ids`, drops street and gate nodes named after their host park, and
  reconciles former-province codes against the 2025 merger membership so a park
  cannot be attributed to a former province its current province never
  absorbed. New columns: `category`, `website`, `part_count`, `osm_ids`,
  `source`, `attribute_source`.

* The official coverage baseline is now recorded in
  `data-raw/industrial-park-baseline.csv` with its source and date rather than
  as a bare constant, and the audit reports mapped area against official area.
  Borderline sites are written to `data-raw/industrial-parks-review.csv` for
  triage instead of being admitted or dropped silently.

# vnmap 0.2.0

## New features

* Adds `economic_zones()` and `geom_economic_zones()` for a conservative,
  evidence-graded catalogue of economic and place-based policy zones. Aggregate
  counts never promote unverified names to established legal status; scope and
  province-only fallback limitations are explicit.

* Added `infrastructure()` and `geom_infrastructure()` with checksum-pinned OSM
  aerodrome, neutral port, border-control and trunk-network geometry. Facility
  aliases/components are reconciled to entities; raw service, lifecycle,
  location-method and source fields remain explicit. Aerodromes are not called
  airports and OSM industrial ports are not called seaports without evidence.

* Added the 3,321-unit current commune boundary geography through
  `vn_map("communes")`, with validity, source, vintage and geometry-accuracy
  metadata.
* Added `download_administrative_crosswalk()` and
  `administrative_crosswalk()` for explicitly downloading and parsing the NSO
  July 2025 old/new commune workbook. The source is not redistributed, partial
  transfers are retained, and no allocation weights are inferred.

* Added `industrial_parks()` and `geom_industrial_parks()` for querying a
  provenance-rich industrial-park `sf` layer and adding it to `plot_vnmap()`.
  Polygon sites are used where redistributable boundaries exist, with point
  fallback and explicit location-accuracy metadata.

* `province_region()` returns the General Statistics Office socio-economic
  region for each unit, and `province_info()` now includes `region_code`,
  `region_vi`, and `region_en` columns.
* `vn_map()` and `plot_vnmap()` gain a `region` argument for selecting whole
  socio-economic regions.
* `plot_vnmap()` gains an experimental `insets` argument that draws enlarged
  copies of small units (by default the centrally governed municipalities).
* `vn_map()` can load optional historical lower-level geographies: the
  district level (`"districts_63"`, `data-raw/build_adm2.R`) and the commune
  level (`"communes_63"`, `data-raw/build_adm3.R`). Both carry `province_code`
  and `province_en` columns and support a `province` filter argument. These
  layers are not bundled by default because of their size.

## Improvements

* `sf` moved from Imports to Suggests. The name, code, and region lookups and
  the bundled statistics now work without `sf`; only the geometry functions
  (`vn_map()`, `plot_vnmap()`, `vnmap_crs()`) require it, and they raise an
  informative error when it is missing.
* The bundled administrative lookup table no longer carries an unused geometry
  column, so `province_info()` always returns a plain data frame.
* Added a "Get started" vignette and a `pkgdown` website.

# vnmap 0.1.0

* Initial release with current 34-unit and historical 63-unit provincial maps.
* Added choropleth plotting, administrative code lookup, and metadata helpers.
