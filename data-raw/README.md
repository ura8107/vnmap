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
