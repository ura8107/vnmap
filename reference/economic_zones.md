# Obtain an evidence-graded economic and policy zone catalogue

Returns a conservative catalogue of Vietnamese place-based policy zones.
Industrial parks are deliberately excluded; use
[`industrial_parks()`](https://ura8107.github.io/vnmap/reference/industrial_parks.md)
for those. Coastal and border-gate catalogues reconcile current
officially reported national counts, but names without row-level legal
instruments are labelled as count-reconciled candidates. EPZ scope is Ho
Chi Minh City, not national. Inspect `baseline_scope` and
`baseline_status` in the build audit before population-level inference.
Some legal economic zones contain industrial parks, but the zone row is
not an industrial-park row.

## Usage

``` r
economic_zones(
  province = NULL,
  type = NULL,
  status = NULL,
  include = NULL,
  as_of = NULL,
  include_unknown = TRUE,
  geometry = c("best", "polygon", "point"),
  crs = vnmap_crs()
)
```

## Arguments

- province:

  Optional current or pre-2025 province identifiers.

- type:

  Optional zone types: `"coastal_economic_zone"`,
  `"border_gate_economic_zone"`, `"export_processing_zone"`, or
  `"national_high_tech_park"`.

- status:

  Optional legal-status values: `"established"` or
  `"candidate_or_count_reconciled"`. The latter means that an official
  aggregate count or non-establishment reference supports inclusion, but
  a row-level establishment instrument has not been verified.

- include:

  Optional IDs, Vietnamese/English names, or aliases.

- as_of:

  Optional date. Zones whose verified establishment effective date is
  later than this date are excluded.

- include_unknown:

  With `as_of`, retain records whose establishment effective date is
  unknown. Defaults to `TRUE` so catalogue records are not silently
  lost; set to `FALSE` for strict dated panels.

- geometry:

  One of `"best"`, `"polygon"`, or `"point"`. `"point"` converts polygon
  zones to an interior point. The initial conservative snapshot contains
  deterministic province-only representative points.

- crs:

  Coordinate reference system understood by
  [`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html).

## Value

An `sf` object in `crs`.

## Examples

``` r
economic_zones(type = "national_high_tech_park")
#> Warning: Economic-zone fallback points identify the associated province only; they are not zone or site locations. Inspect `geometry_available` and `location_accuracy`.
#> Simple feature collection with 3 features and 26 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 580351.3 ymin: 1187475 xmax: 825064.7 ymax: 2319719
#> Projected CRS: VN-2000 / UTM zone 48N
#>                id                                 name_vi
#> 8     htp_da_nang               Khu công nghệ cao Đà Nẵng
#> 7 htp_ho_chi_minh Khu công nghệ cao Thành phố Hồ Chí Minh
#> 6     htp_hoa_lac               Khu công nghệ cao Hòa Lạc
#>                           name_en                  aliases
#> 8          Da Nang High-Tech Park     Da Nang Hi-Tech Park
#> 7 Ho Chi Minh City High-Tech Park Saigon Hi-Tech Park|SHTP
#> 6          Hoa Lac High-Tech Park     Hoa Lac Hi-Tech Park
#>                 zone_type                  legal_status
#> 8 national_high_tech_park                   established
#> 7 national_high_tech_park candidate_or_count_reconciled
#> 6 national_high_tech_park                   established
#>                                   evidence_state operational_status
#> 8    row_level_establishment_instrument_verified            unknown
#> 7 aggregate_count_or_non_establishment_reference            unknown
#> 6    row_level_establishment_instrument_verified            unknown
#>     legal_province province_code      province_en former_province_code
#> 8          Da Nang            48          Da Nang                   48
#> 7 Ho Chi Minh City            79 Ho Chi Minh City                   79
#> 6           Ha Noi            01           Ha Noi                   01
#>   representative_point_province  legal_document established_approval_date
#> 8                            48     1979/QD-TTg                2010-10-28
#> 7                            79 145/2002/QD-TTg                2002-10-24
#> 6                            01      198/QD-TTg                1998-10-12
#>   established_effective_date evidence_date         legal_evidence
#> 8                 2010-10-28    2010-10-28 establishment_decision
#> 7                       <NA>    2002-10-24 establishment_decision
#> 6                       <NA>    1998-10-12 establishment_decision
#>                                                                                                                            source_url
#> 8                                                                    https://vanban.chinhphu.vn/default.aspx?docid=97516&pageid=27160
#> 7 https://vanban.chinhphu.vn/giai-doan-1986-2003-muoi-tam-nam-su-nghiep-doi-moi/iv-chinh-phu-nhiem-ky-quoc-hoi-khoa-xi-2002-2007-2960
#> 6                                                                     https://vanban.chinhphu.vn/default.aspx?docid=5711&pageid=27160
#>   source_date verified_on geometry_type location_accuracy geometry_available
#> 8  2010-10-28  2026-08-12         point     province_only              FALSE
#> 7  2002-10-24  2026-08-12         point     province_only              FALSE
#> 6  1998-10-12  2026-08-12         point     province_only              FALSE
#>                                       geometry_method          geometry_source
#> 8 deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#> 7 deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#> 6 deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#>                   geometry
#> 8 POINT (825064.7 1778928)
#> 7 POINT (680303.9 1187475)
#> 6 POINT (580351.3 2319719)
economic_zones(province = "Ho Chi Minh City", as_of = "2010-01-01")
#> Warning: Economic-zone fallback points identify the associated province only; they are not zone or site locations. Inspect `geometry_available` and `location_accuracy`.
#> Simple feature collection with 4 features and 26 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 680303.9 ymin: 1187475 xmax: 680303.9 ymax: 1187475
#> Projected CRS: VN-2000 / UTM zone 48N
#>                  id                                 name_vi
#> 9  epz_linh_trung_1               Khu chế xuất Linh Trung I
#> 10 epz_linh_trung_2              Khu chế xuất Linh Trung II
#> 5     epz_tan_thuan                  Khu chế xuất Tân Thuận
#> 7   htp_ho_chi_minh Khu công nghệ cao Thành phố Hồ Chí Minh
#>                                 name_en                            aliases
#> 9   Linh Trung I Export Processing Zone  Linh Trung 1 EPZ|Linh Trung EPZ I
#> 10 Linh Trung II Export Processing Zone Linh Trung 2 EPZ|Linh Trung EPZ II
#> 5      Tan Thuan Export Processing Zone                      Tan Thuan EPZ
#> 7       Ho Chi Minh City High-Tech Park           Saigon Hi-Tech Park|SHTP
#>                  zone_type                  legal_status
#> 9   export_processing_zone candidate_or_count_reconciled
#> 10  export_processing_zone candidate_or_count_reconciled
#> 5   export_processing_zone candidate_or_count_reconciled
#> 7  national_high_tech_park candidate_or_count_reconciled
#>                                    evidence_state operational_status
#> 9  aggregate_count_or_non_establishment_reference            unknown
#> 10 aggregate_count_or_non_establishment_reference            unknown
#> 5  aggregate_count_or_non_establishment_reference            unknown
#> 7  aggregate_count_or_non_establishment_reference            unknown
#>      legal_province province_code      province_en former_province_code
#> 9  Ho Chi Minh City            79 Ho Chi Minh City                   79
#> 10 Ho Chi Minh City            79 Ho Chi Minh City                   79
#> 5  Ho Chi Minh City            79 Ho Chi Minh City                   79
#> 7  Ho Chi Minh City            79 Ho Chi Minh City                   79
#>    representative_point_province  legal_document established_approval_date
#> 9                             79     1711/QD-TTg                      <NA>
#> 10                            79     1711/QD-TTg                      <NA>
#> 5                             79 194/2003/QD-BTC                      <NA>
#> 7                             79 145/2002/QD-TTg                2002-10-24
#>    established_effective_date evidence_date
#> 9                        <NA>    2024-12-31
#> 10                       <NA>    2024-12-31
#> 5                        <NA>    2003-11-28
#> 7                        <NA>    2002-10-24
#>                                           legal_evidence
#> 9  official_current_plan_lists_established_and_operating
#> 10 official_current_plan_lists_established_and_operating
#> 5                         official_operational_reference
#> 7                                 establishment_decision
#>                                                                                                                             source_url
#> 9                                     https://congbaocdn.chinhphu.vn/CongBaoCP/VanBan/2024/12/43820/54205-1-2025145-1461711-qd-ttg.pdf
#> 10                                    https://congbaocdn.chinhphu.vn/CongBaoCP/VanBan/2024/12/43820/54205-1-2025145-1461711-qd-ttg.pdf
#> 5                                                                     https://vanban.chinhphu.vn/default.aspx?docid=12414&pageid=27160
#> 7  https://vanban.chinhphu.vn/giai-doan-1986-2003-muoi-tam-nam-su-nghiep-doi-moi/iv-chinh-phu-nhiem-ky-quoc-hoi-khoa-xi-2002-2007-2960
#>    source_date verified_on geometry_type location_accuracy geometry_available
#> 9   2024-12-31  2026-08-12         point     province_only              FALSE
#> 10  2024-12-31  2026-08-12         point     province_only              FALSE
#> 5   2003-11-28  2026-08-12         point     province_only              FALSE
#> 7   2002-10-24  2026-08-12         point     province_only              FALSE
#>                                        geometry_method          geometry_source
#> 9  deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#> 10 deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#> 5  deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#> 7  deterministic_point_on_surface_of_pre_2025_province bundled provinces_63.rds
#>                    geometry
#> 9  POINT (680303.9 1187475)
#> 10 POINT (680303.9 1187475)
#> 5  POINT (680303.9 1187475)
#> 7  POINT (680303.9 1187475)
```
