# Add economic and policy zones to a ggplot map

Add economic and policy zones to a ggplot map

## Usage

``` r
geom_economic_zones(
  data = NULL,
  province = NULL,
  type = NULL,
  status = NULL,
  include = NULL,
  as_of = NULL,
  include_unknown = TRUE,
  geometry = c("best", "polygon", "point"),
  crs = vnmap_crs(),
  polygon_fill = "#6a51a3",
  polygon_colour = "#3f007d",
  point_colour = "#54278f",
  alpha = 0.3,
  linewidth = 0.3,
  point_size = 2
)
```

## Arguments

- data:

  Optional economic-zone `sf` object.

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

- polygon_fill, polygon_colour:

  Polygon colours.

- point_colour:

  Representative-point colour. Province-only fallback points use a cross
  (`shape = 4`) to distinguish them from site locations.

- alpha:

  Polygon opacity.

- linewidth:

  Polygon outline width.

- point_size:

  Representative-point size.

## Value

A list of `ggplot2` layers.

## Examples

``` r
plot_vnmap() + geom_economic_zones(type = "national_high_tech_park")
#> Warning: Economic-zone fallback points identify the associated province only; they are not zone or site locations. Inspect `geometry_available` and `location_accuracy`.
#> Coordinate system already present.
#> ℹ Adding new coordinate system, which will replace the existing one.
```
