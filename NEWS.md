# vnmap (development version)

## Name matching

* Administrative prefixes are now removed on tone-marked word boundaries.
  Previously punctuation was stripped first, so a name whose first syllable
  resembled a prefix lost it: `Tinh Bien`, `Tinh Khe`, `Tinh Gia` and
  `Tinh Tuc` were reduced to their second syllable, and both `Thanh Phong` in
  Thanh Hoa and `Thanh Phong` in Vinh Long normalized to `"ng"`, colliding with
  each other. The word for province carries a hook above where those names
  carry a dot below or a tilde, so requiring the tone to agree separates them.
  Of the 10,807 bundled names and aliases, only the alias
  `"Thanh pho Ho Chi Minh"` changes, which is the intended case.

  `vn_map("communes", include = )` may therefore return different units than
  before for the six affected names. The previous result was wrong.

* Names are now compared with their diacritics intact before being folded to
  ASCII. Ten pairs of communes inside a single province differ only by their
  tone marks, `My Tho` and `My Tho` in Dong Thap among them, so folding first
  destroyed a distinction no province could recover.

* Added `vn_match()`, which reports how every name resolves instead of stopping
  at the first failure: the code found, which normalization step found it,
  which units were considered, and a suggestion for names that found nothing.
  Suggestions are never applied, so a typo produces a message rather than a
  silent substitution.

* `province_code()` resolves exactly what it did before. Its error now names
  the closest unit for each unmatched value, and, when most of the failures
  belong to the other geography, says which one to use. That is the usual
  cause: 29 of the 63 former provincial names no longer exist after the 2025
  reform, so a table prepared under the old geography fails wholesale.

* Added `commune_code()`. Commune names are not unique -- 314 of them are used
  by more than one province -- so a shared name is now an error listing every
  candidate rather than an arbitrary choice. Resolve it with `province`, or by
  writing the value as `"Tan Phu, Dong Nai"`. `vn_map("communes", include = )`
  applies the same rule, after any `province` filter, so a name that is unique
  within the requested province still resolves.

## Provenance

* Added `inst/extdata/manifest.json`, a machine-readable record of every
  bundled dataset: its source, licence and upstream reference, the vintage of
  the geometry, how far it has been generalized, the administrative decision
  its units follow, and the script that builds it. Provenance was previously
  spread across prose in `data-raw/README.md`, `inst/COPYRIGHTS`, checksum CSVs
  and the Rd documentation, and none of it was checked against the data.

* Added `vn_provenance()`, which returns that record as a data frame. Geometry
  in this package comes from more than one upstream source, so the vintage
  belongs to the layer rather than to the package: the current provincial and
  commune layers share a 2026 observed snapshot, while the pre-reform
  provincial layer is derived from geoBoundaries geometry whose represented
  year is 2008.

* The test suite now checks the manifest against the data it describes: every
  described file exists, checksums and row counts match, and no bundled dataset
  is left undescribed. A layer rebuilt without running `make manifest`
  therefore fails rather than quietly describing the previous build.

* `inst/CITATION` reported version 0.1.0 regardless of the installed version.
  It now reads the version from `DESCRIPTION`.

* Added `CITATION.cff`, listing the upstream data sources alongside the
  package itself.


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
