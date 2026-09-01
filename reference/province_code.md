# Look up Vietnamese provincial administrative codes

Names may be written with or without Vietnamese diacritics. Current
names, English names, two-digit codes, and ISO 3166-2 codes are
accepted.

## Usage

``` r
province_code(x, geography = c("provinces", "provinces_63"))
```

## Arguments

- x:

  Character vector of names or codes.

- geography:

  Either `"provinces"` for the current 34-unit geography or
  `"provinces_63"` for the historical 63-unit geography.

## Value

A character vector of two-digit administrative codes.

## Details

Input is matched case-insensitively after punctuation, whitespace,
administrative prefixes, and Vietnamese diacritics are normalized.
Common aliases such as `"Hanoi"`, `"Danang"`, `"HCMC"`, and `"Saigon"`
are supported. An error lists any values that cannot be matched.

Codes are geography-specific. For example, a former province that was
merged in 2025 can be found only with `geography = "provinces_63"`.

## See also

[`province_info()`](https://ura8107.github.io/vnmap/reference/province_info.md),
[`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md)

## Examples

``` r
province_code(c("Da Nang", "Danang", "48"))
#> [1] "48" "48" "48"
province_code(c("HCMC", "Saigon"))
#> [1] "79" "79"
province_code("Bac Giang", geography = "provinces_63")
#> [1] "24"
```
