# Add industrial parks to a ggplot map

Creates `ggplot2` layers that can be added directly to
[`plot_vnmap()`](https://ura8107.github.io/vnmap/reference/plot_vnmap.md).

## Usage

``` r
geom_industrial_parks(
  data = NULL,
  province = NULL,
  category = .ip_register,
  status = NULL,
  include = NULL,
  geometry = c("best", "polygon", "point"),
  attributes = NULL,
  crs = vnmap_crs(),
  polygon_fill = "#e69f00",
  polygon_colour = "#9a6700",
  point_colour = "#b2182b",
  alpha = 0.35,
  linewidth = 0.25,
  point_size = 1.5
)
```

## Arguments

- data:

  Optional industrial park `sf` object.

- province:

  Optional current or pre-2025 provincial identifiers.

- category:

  Designations to return. Defaults to the two designations counted in
  the national industrial-park register, `"industrial_park"` (khu cong
  nghiep) and `"export_processing_zone"` (khu che xuat). Also accepts
  `"hi_tech_park"` and `"industrial_cluster"`, which are separate legal
  categories, or `NULL` for every category.

- status:

  Optional status values: `"operational"`, `"under_construction"`,
  `"established_not_started"`, or `"unknown"`.

- include:

  Optional park identifiers or Vietnamese/English names.

- geometry:

  One of `"best"`, `"polygon"`, or `"point"`. `"point"` converts polygon
  sites to points guaranteed to lie on their surfaces.

- attributes:

  Optional user-supplied basic information: a data frame, or a path to a
  CSV file, with an `id` column. See
  [`industrial_parks_template()`](https://ura8107.github.io/vnmap/reference/industrial_parks_template.md).

- crs:

  Coordinate reference system understood by
  [`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html).

- polygon_fill, polygon_colour:

  Fill and outline colours for polygons.

- point_colour:

  Colour for representative points.

- alpha:

  Polygon opacity.

- linewidth:

  Polygon outline width.

- point_size:

  Point size.

## Value

A list of `ggplot2` layers.

## Examples

``` r
plot_vnmap() + geom_industrial_parks(point_colour = "#b2182b")
#> Coordinate system already present.
#> ℹ Adding new coordinate system, which will replace the existing one.
```
