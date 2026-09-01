# Coordinate reference system used by vnmap

EPSG:3405 is the VN-2000 / UTM zone 48N projected CRS.

## Usage

``` r
vnmap_crs()
```

## Value

An `sf` CRS object.

## Details

All bundled geometries are returned in this projected CRS unless a
different value is supplied to the `crs` argument of
[`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md). Using
a projected CRS keeps distances and polygon rendering stable for
national statistical maps.

## See also

[`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md),
[`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)

## Examples

``` r
vnmap_crs()
#> Coordinate Reference System:
#>   User input: EPSG:3405 
#>   wkt:
#> PROJCRS["VN-2000 / UTM zone 48N",
#>     BASEGEOGCRS["VN-2000",
#>         DATUM["Vietnam 2000",
#>             ELLIPSOID["WGS 84",6378137,298.257223563,
#>                 LENGTHUNIT["metre",1]]],
#>         PRIMEM["Greenwich",0,
#>             ANGLEUNIT["degree",0.0174532925199433]],
#>         ID["EPSG",4756]],
#>     CONVERSION["UTM zone 48N",
#>         METHOD["Transverse Mercator",
#>             ID["EPSG",9807]],
#>         PARAMETER["Latitude of natural origin",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8801]],
#>         PARAMETER["Longitude of natural origin",105,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8802]],
#>         PARAMETER["Scale factor at natural origin",0.9996,
#>             SCALEUNIT["unity",1],
#>             ID["EPSG",8805]],
#>         PARAMETER["False easting",500000,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8806]],
#>         PARAMETER["False northing",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8807]]],
#>     CS[Cartesian,2],
#>         AXIS["(E)",east,
#>             ORDER[1],
#>             LENGTHUNIT["metre",1]],
#>         AXIS["(N)",north,
#>             ORDER[2],
#>             LENGTHUNIT["metre",1]],
#>     USAGE[
#>         SCOPE["Topographic mapping (medium scale)."],
#>         AREA["Vietnam - onshore west of 108°E."],
#>         BBOX[8.33,102.14,23.4,108]],
#>     ID["EPSG",3405]]
```
