# vnmap: Maps of Viet Nam's Provincial-Level Administrative Units

`vnmap` provides convenient `ggplot2` choropleths, `sf` boundary data,
and administrative-code lookup tools for Viet Nam. It supports both the
current 34 provincial-level units effective from 1 July 2025 and the
preceding 63-unit geography used by many historical datasets.

## Main functions

- [`plot_vnmap()`](https://ura8107.github.io/vnmap/reference/plot_vnmap.md)
  draws outline maps and choropleths.

- [`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md)
  returns the bundled boundaries as an `sf` object.

- [`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md)
  converts names and aliases to official codes.

- [`province_info()`](https://ura8107.github.io/vnmap/reference/province_info.md)
  returns the administrative lookup table.

- [`province_region()`](https://ura8107.github.io/vnmap/reference/province_region.md)
  returns the socio-economic region of each unit.

- [`vnmap_crs()`](https://ura8107.github.io/vnmap/reference/vnmap_crs.md)
  returns the package's default projected CRS.

- [province_stats_2024](https://ura8107.github.io/vnmap/reference/province_stats_2024.md)
  contains population and GRDP-per-capita data.

The lookup helpers
([`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md),
[`province_info()`](https://ura8107.github.io/vnmap/reference/province_info.md),
[`province_region()`](https://ura8107.github.io/vnmap/reference/province_region.md))
and the bundled statistics work without the sf package. Only the
geometry functions
([`vn_map()`](https://ura8107.github.io/vnmap/reference/vn_map.md),
[`plot_vnmap()`](https://ura8107.github.io/vnmap/reference/plot_vnmap.md),
[`vnmap_crs()`](https://ura8107.github.io/vnmap/reference/vnmap_crs.md))
require sf to be installed.

## Choosing a geography

Use `geography = "provinces"` for the 34 units effective from July 2025.
Use `geography = "provinces_63"` when mapping statistics recorded under
the preceding administrative structure. Always choose the geography that
matches the reference period and coding scheme of the statistical data.

## Data provenance

Historical 63-province geometry is derived from the public-domain
geoBoundaries Viet Nam ADM1 boundary `VNM-ADM1-63759600`. Current
communes use a pinned MIT-licensed community dataset derived upstream
from Viet Nam's Administrative Units Reference Map; current provinces
are dissolved from those exact commune polygons. Source geometry is
generalized and is appropriate for statistical visualization rather than
surveying, navigation, or legal determinations.

## References

geoBoundaries: <https://www.geoboundaries.org/>

Vietnamese Provinces Database:
<https://github.com/thanglequoc/vietnamese-provinces-database>

## See also

Useful links:

- <https://github.com/ura8107/vnmap>

- <https://ura8107.github.io/vnmap/>

- Report bugs at <https://github.com/ura8107/vnmap/issues>

## Author

**Maintainer**: Yuki Matsuura <matsuura.yuki.200095@gmail.com>

Authors:

- Yuki Matsuura <matsuura.yuki.200095@gmail.com>
