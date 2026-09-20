# Inspect complete industrial-park source lists and unresolved records

Returns every row from the dated Invest Vietnam map feed and the KCN-KKT
discovery list, including rows without an accepted location. These are
source records, not unique parks: multiple records can link to one map
ID. The discovery list includes planned projects and does not verify
legal establishment or operational status. See `source_url`,
`match_method`, `legal_status`, and `reported_coordinate_check` before
interpreting a row.

## Usage

``` r
industrial_park_sources(source = NULL, mapped = NULL)

industrial_park_source_coverage()
```

## Arguments

- source:

  Optional exact source labels, as returned in the source column.

- mapped:

  Optional logical value: `TRUE` returns linked records, `FALSE` returns
  unresolved records, and `NULL` returns both.

## Value

A data frame. Coordinates are WGS84 longitude/latitude; unlinked records
retain missing coordinates rather than province-centroid points.

## Examples

``` r
remaining <- industrial_park_sources(mapped = FALSE)
head(remaining[c("name_vi", "source_url", "review_status")])
#>                                              name_vi
#> 1                                        KCN Đại Kim
#> 2                                         KCN Từ Sơn
#> 3                          KCN Việt Nam - Nhật Bản 1
#> 4                    Băc Ninh - KCN Quế Võ 1 mở rộng
#> 5                           KCN Đại Đồng - Hoàng Sơn
#> 6 Khu công nghiệp Việt Nam Singapore (VSIP Bắc Ninh)
#>                                                                                     source_url
#> 1                           https://investvietnam.gov.vn/vi/kcn.pd/bac-ninh---kcn-dai-kim.html
#> 2                            https://investvietnam.gov.vn/vi/kcn.pd/bac-ninh---kcn-tu-son.html
#> 3                        https://investvietnam.gov.vn/vi/kcn.pd/kcn-viet-nam---nhat-ban-1.html
#> 4                  https://investvietnam.gov.vn/vi/kcn.pd/bac-ninh---kcn-que-vo-1-mo-rong.html
#> 5              https://investvietnam.gov.vn/vi/kcn.pd/bac-ninh---kcn-dai-dong---hoang-son.html
#> 6 https://investvietnam.gov.vn/vi/kcn.pd/khu-cong-nghiep-viet-nam-singapore-vsip-bac-ninh.html
#>                       review_status
#> 1 needs_identity_or_location_review
#> 2 needs_identity_or_location_review
#> 3 needs_identity_or_location_review
#> 4 needs_identity_or_location_review
#> 5 needs_identity_or_location_review
#> 6 needs_identity_or_location_review
industrial_park_source_coverage()
#>                              source source_records linked_records
#> 1                    Invest Vietnam            391            150
#> 2    KCN-KKT discovery (unverified)           1260            172
#> 3 Vietnam Environment Agency (2023)            303            150
#>   unresolved_records distinct_linked_map_sites retrieved_on
#> 1                241                       134   2026-09-10
#> 2               1088                       161   2026-09-10
#> 3                153                       149   2026-09-10
```
