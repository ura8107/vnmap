# Write a basic-information template for industrial parks

Produces the table that
[`industrial_parks()`](https://ura8107.github.io/vnmap/reference/industrial_parks.md)
accepts through its `attributes` argument: one row per park, an `id`
column, and the columns a user may fill in. Rows carrying an `id` that
is already in the bundled layer update that park; rows carrying a new
`id` add a park, and must supply `name_vi`, `province_code`,
`longitude`, and `latitude`.

## Usage

``` r
industrial_parks_template(path = NULL, blank = FALSE, ...)
```

## Arguments

- path:

  Optional file to write. The extension selects the format: `.csv`
  (default) or `.tsv`. When `NULL` the table is only returned.

- blank:

  When `TRUE`, the editable columns are written empty so that the file
  records user-supplied values only. When `FALSE`, the bundled values
  are written as a starting point.

- ...:

  Filters passed to
  [`industrial_parks()`](https://ura8107.github.io/vnmap/reference/industrial_parks.md).

## Value

A data frame, invisibly when `path` is supplied.

## Details

Only non-empty values are applied, so an untouched template changes
nothing.

## Examples

``` r
template <- industrial_parks_template(province = "Dong Nai")
head(template[c("id", "name_vi", "status", "area_ha")])
#>                     id                               name_vi      status
#> 1 osm_node_12535607272 Amata City Long Thanh Industrial Park     unknown
#> 2    osm_way_597919509          Chon Thanh I Industrial Zone operational
#> 3    osm_way_583464295                 Khu công nghiệp Amata operational
#> 4   osm_way_1462512216          Khu công nghiệp Bắc Đồng Phú operational
#> 5   osm_way_1462513965    Khu công nghiệp Bắc Đồng Phú Khu B operational
#> 6    osm_way_321136900               Khu công nghiệp Bàu Xéo operational
#>    area_ha
#> 1       NA
#> 2 246.3112
#> 3 600.1156
#> 4 167.1046
#> 5 408.1200
#> 6 524.0327
```
