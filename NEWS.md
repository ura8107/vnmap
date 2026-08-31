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

* Rebuilt the industrial-park layer as a national registry with one row per
  park rather than one row per OpenStreetMap element. Parks that OpenStreetMap
  names but has not drawn - through an entrance gate, a bus stop, an internal
  road or a plant inside them - now enter the registry as locality-accuracy
  records, and phases of one park drawn as several areas are merged. Records
  gain `park_key`, `category`, `commune_code`, `commune_name`,
  `former_province_en`, `short_name`, `geometry_source`, `feature_count`,
  `osm_refs`, `lon` and `lat`, and `industrial_parks()` gains `category` and
  `accuracy` filters. Identifiers are now stable registry keys such as
  `VN-IP-75-bien-hoa-2`; the contributing OpenStreetMap element URLs remain in
  `osm_refs`.

* Added `industrial_park_registry()`, which returns the same records as a plain
  data frame without requiring `sf`, and `industrial_park_coverage()`, which
  reports mapped parks per province and compares the registry with the official
  national count of established industrial parks (478 as of 30 September 2025,
  Foreign Investment Agency, Ministry of Finance).

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
