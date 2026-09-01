# Obtain industrial park map data

Returns Vietnamese industrial parks with the best redistributable
geometry available for each park. Polygon boundaries are retained where
a mapped site boundary is available; otherwise a representative point is
used.

## Usage

``` r
industrial_parks(
  province = NULL,
  category = .ip_register,
  status = NULL,
  include = NULL,
  geometry = c("best", "polygon", "point"),
  attributes = NULL,
  crs = vnmap_crs()
)
```

## Arguments

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

## Value

An `sf` object. See
[industrial_parks_data](https://ura8107.github.io/vnmap/reference/industrial_parks_data.md)
for data provenance.

## Details

The bundled layer is a mapped subset, not the national register: see
[industrial_parks_data](https://ura8107.github.io/vnmap/reference/industrial_parks_data.md)
for the coverage gap against the official count of established parks.
Use `attributes` to supply parks or attribute values the snapshot does
not carry, and
[`industrial_parks_template()`](https://ura8107.github.io/vnmap/reference/industrial_parks_template.md)
to produce a file in the expected shape.

## See also

[`industrial_parks_template()`](https://ura8107.github.io/vnmap/reference/industrial_parks_template.md)
and
[`write_industrial_parks()`](https://ura8107.github.io/vnmap/reference/write_industrial_parks.md)
for reading and writing basic information,
[`geom_industrial_parks()`](https://ura8107.github.io/vnmap/reference/geom_industrial_parks.md)
for mapping.

## Examples

``` r
parks <- industrial_parks(province = "Dong Nai")
points <- industrial_parks(geometry = "point", crs = 4326)
clusters <- industrial_parks(category = "industrial_cluster")
```
