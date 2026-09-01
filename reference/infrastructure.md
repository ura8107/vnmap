# Obtain transport and logistics infrastructure

Obtain transport and logistics infrastructure

## Usage

``` r
infrastructure(
  type = NULL,
  status = NULL,
  province = NULL,
  include = NULL,
  class = NULL,
  service = NULL,
  geometry = c("any", "point", "line"),
  crs = vnmap_crs()
)
```

## Source

OpenStreetMap contributors, Open Database License (ODbL) 1.0,
<https://www.openstreetmap.org/copyright>. The facility snapshot has OSM
base timestamp 9 July 2026 and retrieval date 11 August 2026. Network
lines use the checksum-pinned Geofabrik Viet Nam extract dated 10 August
2026.

## Arguments

- type:

  Optional values among `"port"`, `"aerodrome"`, `"border_control"`,
  `"expressway"`, `"national_highway"`, and `"railway"`.

- status:

  Optional lifecycle status. Supported values are `"operational"`,
  `"under_construction"`, `"planned"`, `"disused"`, `"abandoned"`, and
  `"unknown"`.

- province:

  Optional current province names or codes.

- include:

  Optional infrastructure IDs or names.

- class:

  Optional facility subclass, such as `"military_aerodrome"`,
  `"fishing_port"`, `"rail_yard"`, or `"rail_siding"`.

- service:

  Optional service classification, such as
  `"commercial_service_candidate"`, `"service=yard"`, or `"usage=main"`.

- geometry:

  `"any"`, `"point"`, or `"line"`.

- crs:

  Output CRS.

## Value

An `sf` object containing point and line geometry.

## Details

Coordinates are a pinned ODbL OpenStreetMap snapshot, not an official
register. Status is classified only when lifecycle tags state it;
otherwise it is `"unknown"`. No legal opening date is inferred.
`"aerodrome"` does not imply scheduled commercial service, and `"port"`
does not imply a seaport. Consult `infrastructure_class`,
`status_source`, `location_accuracy`, and the retained raw OSM tag
columns.

Trunk lines come from the checksum-pinned Geofabrik Vietnam OSM extract.
They are generalized to 100 metres for statistical graphics. Lifecycle
status is never inferred from road class or map presence. Facility
aliases and nearby border-control components are reconciled to entity
IDs. Points just outside generalized land geometry are retained only
within 15 km and identified in `country_relation`. `province_code` is a
scalar nearest-parent code for points only. It is `NA` for lines, whose
intersected parents are listed in pipe-delimited `province_codes`.
Province filtering always uses geometry intersection; the point code is
only a fallback for flagged near-boundary facilities.

## Examples

``` r
infrastructure(type = "aerodrome", province = "Ha Noi")
#> Simple feature collection with 3 features and 39 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 550550.4 ymin: 2325737 xmax: 591985.8 ymax: 2346740
#> Projected CRS: VN-2000 / UTM zone 48N
#>                                                 id             entity_id
#> aerodrome sanbayquoctenoibai osm-relation-20136775 osm-relation-20136775
#> aerodrome sanbayhoalac          osm-way-1016759175    osm-way-1016759175
#> aerodrome sanbaygialam           osm-way-217455233     osm-way-217455233
#>                                              name_vi
#> aerodrome sanbayquoctenoibai Sân bay Quốc tế Nội Bài
#> aerodrome sanbayhoalac               Sân bay Hòa Lạc
#> aerodrome sanbaygialam               Sân bay Gia Lâm
#>                                                    name_en
#> aerodrome sanbayquoctenoibai Noi Bai International Airport
#> aerodrome sanbayhoalac                    Hoa Lac Air Base
#> aerodrome sanbaygialam                     Gia Lam Airport
#>                                                                                                                                  aliases
#> aerodrome sanbayquoctenoibai Noi Bai International Airport|Noi Bai International Airport|Sân bay Quốc tế Nội Bài|Sân bay Quốc tế Nội Bài
#> aerodrome sanbayhoalac                                                 Hoa Lac Air Base|Hoa Lac Air Base|Sân bay Hòa Lạc|Sân bay Hòa Lạc
#> aerodrome sanbaygialam                                                   Gia Lam Airport|Gia Lam Airport|Sân bay Gia Lâm|Sân bay Gia Lâm
#>                                         source_ids infrastructure_type
#> aerodrome sanbayquoctenoibai osm-relation-20136775           aerodrome
#> aerodrome sanbayhoalac          osm-way-1016759175           aerodrome
#> aerodrome sanbaygialam           osm-way-217455233           aerodrome
#>                               infrastructure_class                 service_type
#> aerodrome sanbayquoctenoibai aerodrome_unspecified commercial_service_candidate
#> aerodrome sanbayhoalac          military_aerodrome      service_not_established
#> aerodrome sanbaygialam       aerodrome_unspecified      service_not_established
#>                              facility_role facility_roles  status status_source
#> aerodrome sanbayquoctenoibai      facility       facility unknown          none
#> aerodrome sanbayhoalac            facility       facility unknown          none
#> aerodrome sanbaygialam            facility       facility unknown          none
#>                              province_code province_en geometry_type
#> aerodrome sanbayquoctenoibai            01      Ha Noi         point
#> aerodrome sanbayhoalac                  01      Ha Noi         point
#> aerodrome sanbaygialam                  01      Ha Noi         point
#>                              location_accuracy source_geometry_method osm_type
#> aerodrome sanbayquoctenoibai   bounds_midpoint        bounds_midpoint relation
#> aerodrome sanbayhoalac         bounds_midpoint        bounds_midpoint      way
#> aerodrome sanbaygialam         bounds_midpoint        bounds_midpoint      way
#>                              osm_ref iata icao access military aerodrome_type
#> aerodrome sanbayquoctenoibai     HAN  HAN VVNB   <NA>     <NA>  international
#> aerodrome sanbayhoalac          <NA> <NA> <NA>   <NA> airfield           <NA>
#> aerodrome sanbaygialam          <NA> <NA> VVGL   <NA>     <NA>           <NA>
#>                              valid_from valid_to snapshot_date observed_on
#> aerodrome sanbayquoctenoibai       <NA>     <NA>    2026-07-09  2026-08-11
#> aerodrome sanbayhoalac             <NA>     <NA>    2026-07-09  2026-08-11
#> aerodrome sanbaygialam             <NA>     <NA>    2026-07-09  2026-08-11
#>                              source_authority
#> aerodrome sanbayquoctenoibai        community
#> aerodrome sanbayhoalac              community
#> aerodrome sanbaygialam              community
#>                                                 verification_status
#> aerodrome sanbayquoctenoibai not_verified_against_official_register
#> aerodrome sanbayhoalac       not_verified_against_official_register
#> aerodrome sanbaygialam       not_verified_against_official_register
#>                                                                 source_snapshot
#> aerodrome sanbayquoctenoibai OSM base 2026-07-09T00:07:45Z retrieved 2026-08-11
#> aerodrome sanbayhoalac       OSM base 2026-07-09T00:07:45Z retrieved 2026-08-11
#> aerodrome sanbaygialam       OSM base 2026-07-09T00:07:45Z retrieved 2026-08-11
#>                                         country_relation distance_to_country_m
#> aerodrome sanbayquoctenoibai inside_generalized_boundary                     0
#> aerodrome sanbayhoalac       inside_generalized_boundary                     0
#> aerodrome sanbaygialam       inside_generalized_boundary                     0
#>                              province_codes province_assignment_method
#> aerodrome sanbayquoctenoibai             01   nearest_parent_for_point
#> aerodrome sanbayhoalac                   01   nearest_parent_for_point
#> aerodrome sanbaygialam                   01   nearest_parent_for_point
#>                              railway_service railway_usage
#> aerodrome sanbayquoctenoibai            <NA>          <NA>
#> aerodrome sanbayhoalac                  <NA>          <NA>
#> aerodrome sanbaygialam                  <NA>          <NA>
#>                                                                   source_url
#> aerodrome sanbayquoctenoibai https://www.openstreetmap.org/relation/20136775
#> aerodrome sanbayhoalac          https://www.openstreetmap.org/way/1016759175
#> aerodrome sanbaygialam           https://www.openstreetmap.org/way/217455233
#>                                              geometry
#> aerodrome sanbayquoctenoibai POINT (583061.1 2346740)
#> aerodrome sanbayhoalac       POINT (550550.4 2325737)
#> aerodrome sanbaygialam       POINT (591985.8 2327003)
```
