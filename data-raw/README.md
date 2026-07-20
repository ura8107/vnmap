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
