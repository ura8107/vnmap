# Socio-economic region of Vietnamese provincial units

Returns the socio-economic region that each provincial-level unit
belongs to. Regions follow the six-region scheme published by the
General Statistics Office of Viet Nam.

## Usage

``` r
province_region(x = NULL, geography = c("provinces", "provinces_63"))
```

## Arguments

- x:

  Optional names or codes accepted by
  [`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md).
  When omitted, every unit is returned in ascending code order.

- geography:

  Either `"provinces"` for the current 34-unit geography or
  `"provinces_63"` for the historical 63-unit geography.

## Value

A character vector of English region names. When `x` is omitted the
vector is named by administrative code.

## Details

The six regions are the Red River Delta (`RRD`), Northern Midlands and
Mountains (`NMM`), North Central and Central Coast (`NCC`), Central
Highlands (`CH`), Southeast (`SE`), and Mekong River Delta (`MRD`).

Region assignments for the 63-unit geography are the official ones.
Assignments for the 34 current units are derived: each 2025 unit is
placed in the region holding the largest share of its 2024 population
among the former units it absorbed. Use
[`province_info()`](https://ura8107.github.io/vnmap/reference/province_info.md)
to obtain the region code and Vietnamese region name alongside the
English name.

## See also

[`province_info()`](https://ura8107.github.io/vnmap/reference/province_info.md),
[`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md),
[`plot_vnmap()`](https://ura8107.github.io/vnmap/reference/plot_vnmap.md)

## Examples

``` r
province_region(c("HCMC", "Can Tho"))
#> [1] "Southeast"          "Mekong River Delta"
province_region("Bac Giang", geography = "provinces_63")
#> [1] "Northern Midlands and Mountains"
head(province_region())
#>                                01                                04 
#>                 "Red River Delta" "Northern Midlands and Mountains" 
#>                                08                                11 
#> "Northern Midlands and Mountains" "Northern Midlands and Mountains" 
#>                                12                                14 
#> "Northern Midlands and Mountains" "Northern Midlands and Mountains" 
```
