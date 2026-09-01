# Provincial population and economic indicators under the 63-unit geography

The official 2024 source values before aggregation to Viet Nam's current
34-unit provincial geography.

## Usage

``` r
province_stats_2024_63
```

## Format

A data frame with 63 rows and 12 variables. Variables correspond to
those in
[province_stats_2024](https://ura8107.github.io/vnmap/reference/province_stats_2024.md),
except that `iso` replaces `member_codes`.

## Source

General Statistics Office of Viet Nam, PX-Web tables, accessed 13 July
2026. <https://pxweb.nso.gov.vn/>

## Examples

``` r
data(province_stats_2024_63)
plot_vnmap(
  geography = "provinces_63",
  data = province_stats_2024_63,
  values = "population_density",
  id = "code"
)
```
