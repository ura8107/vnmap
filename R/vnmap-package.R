#' vnmap: Maps of Viet Nam's Provincial-Level Administrative Units
#'
#' `vnmap` provides convenient `ggplot2` choropleths, `sf` boundary data, and
#' administrative-code lookup tools for Viet Nam. It supports both the current
#' 34 provincial-level units effective from 1 July 2025 and the preceding
#' 63-unit geography used by many historical datasets.
#'
#' @section Main functions:
#' \itemize{
#'   \item [plot_vnmap()] draws outline maps and choropleths.
#'   \item [vn_map()] returns the bundled boundaries as an `sf` object.
#'   \item [province_code()] converts names and aliases to official codes.
#'   \item [province_info()] returns the administrative lookup table.
#'   \item [province_region()] returns the socio-economic region of each unit.
#'   \item [vnmap_crs()] returns the package's default projected CRS.
#'   \item [province_stats_2024] contains population and GRDP-per-capita data.
#' }
#'
#' The lookup helpers ([province_code()], [province_info()],
#' [province_region()]) and the bundled statistics work without the \pkg{sf}
#' package. Only the geometry functions ([vn_map()], [plot_vnmap()],
#' [vnmap_crs()]) require \pkg{sf} to be installed.
#'
#' @section Choosing a geography:
#' Use `geography = "provinces"` for the 34 units effective from July 2025.
#' Use `geography = "provinces_63"` when mapping statistics recorded under the
#' preceding administrative structure. Always choose the geography that
#' matches the reference period and coding scheme of the statistical data.
#'
#' @section Data provenance:
#' Historical 63-province geometry is derived from the public-domain
#' geoBoundaries Viet Nam ADM1 boundary `VNM-ADM1-63759600`. Current communes
#' use a pinned MIT-licensed community dataset derived upstream from Viet Nam's
#' Administrative Units Reference Map; current provinces are dissolved from
#' those exact commune polygons. Source geometry is generalized and is
#' appropriate for statistical visualization rather than surveying,
#' navigation, or legal determinations.
#'
#' @references
#' geoBoundaries: \url{https://www.geoboundaries.org/}
#'
#' Vietnamese Provinces Database:
#' \url{https://github.com/thanglequoc/vietnamese-provinces-database}
#'
"_PACKAGE"
