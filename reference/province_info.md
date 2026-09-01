# Retrieve metadata for Vietnamese provincial units

Returns the lookup table used by `vnmap` to join statistical data to map
geometry. Supplying `x` filters and orders the result to match the
input.

## Usage

``` r
province_info(x = NULL, geography = c("provinces", "provinces_63"))
```

## Arguments

- x:

  Optional names or codes. When omitted, returns every unit.

- geography:

  Either `"provinces"` for the current 34-unit geography or
  `"provinces_63"` for the historical 63-unit geography.

## Value

A data frame containing `code`, `iso`, `name_vi`, `name_en`, `type`,
`region_code`, `region_vi`, and `region_en`. The `type` column
distinguishes provinces from centrally governed municipalities, and the
`region_*` columns give the socio-economic region (see
[`province_region()`](https://ura8107.github.io/vnmap/reference/province_region.md)).

## Details

With no `x`, rows are returned in ascending official code order. With
`x`, names and aliases are normalized by
[`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md)
and the returned rows follow the order of `x`.

## See also

[`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md),
[`province_region()`](https://ura8107.github.io/vnmap/reference/province_region.md),
[`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md)

## Examples

``` r
head(province_info())
#>   code  iso     name_vi     name_en         type region_code
#> 1   01 <NA>      Hà Nội      Ha Noi municipality         RRD
#> 2   04 <NA>    Cao Bằng    Cao Bang     province         NMM
#> 3   08 <NA> Tuyên Quang Tuyen Quang     province         NMM
#> 4   11 <NA>   Điện Biên   Dien Bien     province         NMM
#> 5   12 <NA>    Lai Châu    Lai Chau     province         NMM
#> 6   14 <NA>      Sơn La      Son La     province         NMM
#>                       region_vi                       region_en
#> 1           Đồng bằng sông Hồng                 Red River Delta
#> 2 Trung du và miền núi phía Bắc Northern Midlands and Mountains
#> 3 Trung du và miền núi phía Bắc Northern Midlands and Mountains
#> 4 Trung du và miền núi phía Bắc Northern Midlands and Mountains
#> 5 Trung du và miền núi phía Bắc Northern Midlands and Mountains
#> 6 Trung du và miền núi phía Bắc Northern Midlands and Mountains
province_info(c("01", "HCMC"))
#>    code  iso               name_vi          name_en         type region_code
#> 1    01 <NA>                Hà Nội           Ha Noi municipality         RRD
#> 28   79 <NA> Thành phố Hồ Chí Minh Ho Chi Minh City municipality          SE
#>              region_vi       region_en
#> 1  Đồng bằng sông Hồng Red River Delta
#> 28         Đông Nam Bộ       Southeast
province_info("Bac Giang", geography = "provinces_63")
#>    code   iso   name_vi   name_en     type region_code
#> 15   24 VN-54 Bắc Giang Bac Giang province         NMM
#>                        region_vi                       region_en
#> 15 Trung du và miền núi phía Bắc Northern Midlands and Mountains
```
