# Write industrial park data to a file

Exports an industrial park layer for use outside R. CSV output drops the
geometry column and adds representative `longitude` and `latitude`
columns, so it round-trips through
[`industrial_parks()`](https://ura8107.github.io/vnmap/reference/industrial_parks.md)'s
`attributes` argument; GeoJSON and GeoPackage output keep the mapped
boundaries.

## Usage

``` r
write_industrial_parks(x, path, format = NULL, ...)
```

## Arguments

- x:

  An `sf` object from
  [`industrial_parks()`](https://ura8107.github.io/vnmap/reference/industrial_parks.md).

- path:

  Output file. The extension selects the format unless `format` is
  given.

- format:

  One of `"csv"`, `"geojson"`, or `"gpkg"`.

- ...:

  Passed to
  [`sf::st_write()`](https://r-spatial.github.io/sf/reference/st_write.html)
  for the spatial formats.

## Value

`path`, invisibly.

## Examples

``` r
parks <- industrial_parks(province = "Dong Nai")
file <- tempfile(fileext = ".csv")
write_industrial_parks(parks, file)
```
