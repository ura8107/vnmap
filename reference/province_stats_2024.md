# Provincial population and economic indicators, 2024

Official 2024 area, average population, population density, and gross
regional domestic product (GRDP) per capita for the current 34
provincial units of Viet Nam. Values for units created in 2025 are
aggregated from the 63-unit geography in which the statistics were
published.

## Usage

``` r
province_stats_2024
```

## Format

A data frame with 34 rows and 12 variables:

- code:

  Current two-digit administrative code.

- name_vi, name_en:

  Vietnamese and English unit names.

- type:

  Province or centrally governed municipality.

- year:

  Reference year, 2024.

- area_km2:

  Land area in square kilometres.

- population:

  Average population, in persons.

- population_thousands:

  Average population, in thousands of persons.

- population_density:

  Population divided by area, persons per km2.

- grdp_per_capita_million_vnd:

  GRDP per capita, million current VND.

- grdp_preliminary:

  Whether the GRDP value is preliminary.

- member_codes:

  Codes of the pre-2025 units used in aggregation.

## Source

General Statistics Office of Viet Nam, PX-Web tables "Area, population
and population density by province" and "Gross regional domestic product
per capita by province", accessed 13 July 2026.
<https://pxweb.nso.gov.vn/>

## Details

Population and area are summed across member units. Population density
is recalculated from those totals. GRDP per capita is population-
weighted, which is equivalent to summing estimated provincial GRDP and
dividing by the combined population. Because published inputs are
rounded, aggregated figures should be treated as estimates.

## Examples

``` r
data(province_stats_2024)
head(province_stats_2024)
#>   code     name_vi     name_en         type year area_km2 population
#> 1   01      Hà Nội      Ha Noi municipality 2024   3359.8    8717600
#> 2   04    Cao Bằng    Cao Bang     province 2024   6700.4     558500
#> 3   08 Tuyên Quang Tuyen Quang     province 2024  13795.6    1731700
#> 4   11   Điện Biên   Dien Bien     province 2024   9539.9     656700
#> 5   12    Lai Châu    Lai Chau     province 2024   9068.7     495500
#> 6   14      Sơn La      Son La     province 2024  14108.9    1330600
#>   population_thousands population_density grdp_per_capita_million_vnd
#> 1               8717.6         2594.67825                   162.90000
#> 2                558.5           83.35323                    44.20000
#> 3               1731.7          125.52553                    48.31606
#> 4                656.7           68.83720                    47.70000
#> 5                495.5           54.63848                    60.40000
#> 6               1330.6           94.30927                    57.40000
#>   grdp_preliminary member_codes
#> 1             TRUE           01
#> 2             TRUE           04
#> 3             TRUE        02+08
#> 4             TRUE           11
#> 5             TRUE           12
#> 6             TRUE           14
plot_vnmap(
  data = province_stats_2024,
  values = "grdp_per_capita_million_vnd",
  id = "code"
)
```
