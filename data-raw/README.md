# Boundary data build

Run `Rscript data-raw/build_data.R` from the package root to regenerate the
four files under `inst/extdata/`.

## Geometry source

The input file is the simplified GeoJSON for geoBoundaries boundary
`VNM-ADM1-63759600`:

* boundary: Viet Nam ADM1 municipalities and provinces
* represented year: 2008
* source build: 12 December 2023
* license: Public Domain
* upstream URL: <https://www.geoboundaries.org/>

The source contains Ha Tay as a separate unit and Con Dao as a separate
feature. The build assigns Ha Tay to Ha Noi and Con Dao to Ba Ria-Vung Tau,
then constructs the 63-unit layer. The current 34-unit layer is created by
dissolving those geometries according to the merger membership table in
`provinces_34.csv`.

The names and two-digit codes for the current units follow Viet Nam Decision
19/2025/QD-TTg, effective 1 July 2025. Geographic shapes remain derived from
the older source and are therefore suitable for statistical graphics, not
surveying or legal boundary determinations.

## Statistical data

Run `Rscript data-raw/fetch_nso_stats.R` to download the official 2024
province-level tables and regenerate `data/province_stats_2024_63.rda` and
`data/province_stats_2024.rda`. The script uses these General Statistics Office
of Viet Nam PX-Web tables:

* Area, population and population density by province (2024)
* Gross regional domestic product per capita by province (preliminary 2024)

The unaggregated cleaned inputs are retained in
`source/nso_province_stats_2024_63.csv`. The current 34-unit data sum area and
population across merger members, recalculate density, and calculate GRDP per
capita as a population-weighted mean. This preserves implied total GRDP subject
to rounding in the published source values.

## Socio-economic regions

Run `Rscript data-raw/build_regions.R` (base R only, no `sf`) to regenerate
`inst/extdata/regions.rds`. The six socio-economic regions follow the General
Statistics Office of Viet Nam. Region assignments for the historical 63 units
come directly from `regions_63.csv`. Assignments for the current 34 units are
derived: each 2025 unit is placed in the region holding the largest share of
its 2024 population among the former units it absorbed. Several 2025 mergers
crossed regional lines, so this rule is applied deterministically from the
`province_stats_2024_63` population totals.

## Lower-level (ADM2 / ADM3) geographies

### Current commune geography and the 2025 crosswalk

Run `Rscript data-raw/build_communes.R` to regenerate the bundled
`inst/extdata/communes.rds` and the source-compatible
`inst/extdata/provinces.rds`. The build uses a fixed 25 July 2026 community
administrative-code snapshot and fixed-commit GeoJSON derived upstream from
the Viet Nam Administrative Units
Reference Map. The upstream repository distributes its derived dataset under
the MIT License. This is not itself an official legal-boundary dataset. Set
`VNMAP_COMMUNE_GEOMETRY_DIR` to a directory of the 3,321 downloaded GeoJSON
files for an offline deterministic rebuild. Every geometry is validated
against `commune-geometry-md5.csv` before use.

Province polygons are unions of their member communes. Because independently
simplified neighbours can overlap slightly, the build assigns overlaps in
ascending province-code order, verifies that national coverage is unchanged,
within a `1e-8` relative area tolerance, and rejects projected pairwise overlap
slivers larger than 1,000 square metres (well below the 100 m generalization
scale).

The NSO old/new conversion workbook has no redistribution terms established
for this package, so neither the workbook nor an extracted table is bundled.
`download_administrative_crosswalk()` performs an explicit user-requested
download and `administrative_crosswalk()` parses it locally. It exposes the
many-to-many relationships, partial transfers, and differences between the
July 2025 transition table and the July 2026 geometry snapshot without
inventing weights or per-code effective dates.

The bundled commune geometry is simplified to 100 metres for statistical
graphics and package size. It is not a legal boundary or surveying product.

### Historical pre-reform layers

Run `Rscript data-raw/build_adm2.R` (district level) or
`Rscript data-raw/build_adm3.R` (commune level) to generate the optional
`inst/extdata/districts_63.rds` and `inst/extdata/communes_63.rds` layers
returned by `vn_map("districts_63")` and `vn_map("communes_63")`. Both require
`sf` and internet access and read from geoBoundaries Viet Nam ADM2 / ADM3.

Each script assigns every unit to a pre-July-2025 (63-unit) province by spatial
containment of a representative interior point, so the layers carry
`province_code` and `province_en` columns for filtering with the `province`
argument of `vn_map()`.

The July 2025 reform abolished the district tier and merged communes, so both
layers are historical only: they describe units as they existed before
1 July 2025 and are intended for visualizing pre-reform data. They are not
built or bundled by default and are excluded from the package build via
`.Rbuildignore` (the commune layer in particular has many thousands of polygons
and would exceed the CRAN size limit). Commune names are not unique nationwide,
so filter with `province` and join on `province_code` together with the name.

## Industrial parks

Run `Rscript data-raw/build_industrial_parks.R` to regenerate
`inst/extdata/industrial_parks.rds`, `inst/extdata/industrial_park_registry.rds`,
`inst/extdata/industrial_park_baseline.rds`, the reviewable text mirror
`industrial-parks-registry.csv`, and `industrial-parks-audit.csv`. Set
`VNMAP_OSM_FILE` to a saved Overpass JSON response for a reproducible dated
rebuild; the pinned 2026-08-11 snapshot under `source/` is used by default.

The Overpass request matches every Vietnamese feature whose name mentions an
industrial park, export-processing zone or industrial cluster, and the build
mines two kinds of evidence from it:

* **site features** carry `landuse=industrial` or `industrial=industrial_park`
  and supply the park's boundary;
* **reference features** are everything else that names a park - an entrance
  gate, a bus stop, an internal road, a plant inside it. They supply no
  boundary but do place the park, so a park OpenStreetMap has not drawn still
  earns a record at `location_accuracy = "locality"`.

Names are reduced to a diacritic-free `park_key` by taking the words that
follow the category keyword up to the first address or route marker. The marker
lists are deliberately shaped: Vietnamese park names reuse the same syllables as
address words once diacritics are gone, so `duong` cuts "Hai Duong" only when a
road number follows, `xa` cuts only when another word follows it, and phrases
such as `doi dien`, `noi bo` and `thanh pho` cut only as pairs. Keys are then
clustered within a province at a 5 km single linkage, so phases of one park
drawn as several areas and signposted from several directions collapse to one
row, and a reference-only cluster is dropped when the same key is already drawn
as a site in that province.

Records that survive parsing but do not denote a park - a management board, a
warehouse address, a fragment of a longer name - are listed with a reason in
`industrial-parks-exclusions.csv` and removed by key, optionally scoped to one
province. Former-province assignment is constrained to the merger members of
the park's current province, because the 63-unit layer comes from a coarser
public-domain source and a point near a former boundary can otherwise land in a
unit that never merged into that province.

OpenStreetMap geometry is used under ODbL 1.0.
`industrial-park-official-baseline.csv` holds the cited official national
totals - 478 established industrial parks over about 145,970 ha as of
30 September 2025, from the Foreign Investment Agency (Ministry of Finance) -
against which `industrial-parks-audit.csv` and `industrial_park_coverage()`
measure mapping coverage. Missing parks remain explicit coverage gaps rather
than being replaced with province centroids.

## Economic and policy zones

`build_economic_zones.R` builds a conservative, evidence-graded catalogue.
Only rows joining the canonical instrument table to a verified direct official
establishment URL are labelled `established`; aggregate-count name
reconciliations remain candidates. Industrial parks remain separate. Coordinates are
derived deterministically with `st_point_on_surface()` from the same bundled
pre-2025 province geometry used elsewhere in vnmap; no legal boundary or exact
site is inferred and no web-map geometry is copied.

`economic-zones-audit.csv` distinguishes current scope and evidence strength:
20 coastal and 26 border-gate rows match current official national counts, but
the names are not claimed as a legally reconciled national register;
the historical national-plan vintage contained 18 coastal zones before two
later establishment decisions. The three-EPZ baseline is explicitly Ho Chi
Minh City-only. Three named high-tech parks are included, but national
high-tech-park completeness is unknown.
Missing zone-level decision dates remain `NA`; evidence dates are separate.
`economic-zone-legal-instruments.csv` normalizes one row per legal document.

## Transport and logistics infrastructure

Run `Rscript data-raw/build_infrastructure.R` to regenerate the bundled
facility points, trunk-network lines and `data-raw/infrastructure-audit.csv`.
The pinned Overpass input and Geofabrik-derived line extract are checksum
validated and redistributed under ODbL 1.0. Acquisition commands and queries
are recorded in `acquire_infrastructure_osm.sh`, `acquire_geofabrik_pbf.sh`,
and `extract_osm_network.R`. The facility response has an OSM base timestamp of
9 July 2026 and was retrieved on 11 August 2026; those dates remain separate in
the output metadata.

The build emits 42 aerodrome entities, 80 neutral port features and 32
border-control entities after normalization. Aerodrome class and possible
commercial service are separate fields. Port features are never promoted to
seaports from `industrial=port` alone. Border posts, control stations and
management offices within 150 metres are grouped with their crossing and kept
as aliases/roles instead of being double counted. Exact OSM nodes, OSM-provided
centres and bounding-box midpoints have distinct location methods. Coastal and
border points within 15 km of the generalized national polygon are retained
with an explicit `country_relation` rather than silently discarded.

Trunk-network ways are generalized to 100 metres for statistical graphics and
package size. Original OSM way IDs and URLs remain available for applications
that require unsimplified geometry; the bundled lines are not for navigation.
The current snapshot contains 7,650 expressway, 22,648 national-highway and
3,739 railway OSM way segments after clipping. A further 195 source ways that
did not intersect the generalized Viet Nam polygon are recorded as excluded in
`infrastructure-network-audit.csv`. Expressways are selected from motorway classes
or `CT` references, national highways from `QL` references, and railways from
rail/construction/proposed/disused/abandoned values. Consequently, untagged or
nonstandard-reference segments are coverage gaps; counts are OSM way segments,
not route counts or official network lengths.
Railway `service` and `usage` tags are retained. Yards, sidings, spurs,
crossovers, industrial and branch lines receive distinct classes; only records
explicitly carrying `usage=main` are called `main_line`. Network rows have no
scalar `province_code`; `province_codes` lists actual polygon intersections.

`infrastructure-audit.csv` is row-level: each source feature is marked
`included`, `duplicate`, or `excluded`, with the reason and retained entity ID.
The current audit contains 154 retained facility entities, eight duplicate
source representations/components, 85 unnamed exclusions and two obvious
non-port exclusions. These are community-mapped features, not an official
register, and no completeness claim is made.
