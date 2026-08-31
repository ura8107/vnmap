#' Vietnamese industrial parks with mapped locations
#'
#' The national industrial-park registry bundled with the package: one row per
#' park, built from a dated OpenStreetMap snapshot and linked to both the
#' current 34-unit and former 63-unit provincial geographies as well as the
#' current commune geography.
#'
#' Two kinds of OpenStreetMap evidence contribute. Where the park is drawn as
#' an industrial landuse area, that boundary is kept and
#' `location_accuracy` is `"site"`. Where it is only named by an entrance gate,
#' a bus stop, an internal road or a plant inside it, the park still earns a
#' record placed at the centre of those references, with `location_accuracy`
#' `"locality"` and no `area_ha`. Features are matched to one another on a
#' diacritic-free `park_key` and clustered within a province, so a park drawn
#' in several phases and signposted from several directions is a single row.
#'
#' The registry is conservative: a park enters it only when a redistributable
#' mapped location exists, so it is smaller than the official register and its
#' completeness varies by province. Use [industrial_park_coverage()] to see the
#' gap rather than assuming the registry is exhaustive.
#'
#' @name industrial_parks_data
#' @format An internal object with one row per park and the columns:
#' \describe{
#'   \item{id}{Stable registry identifier, `VN-<category tag>-<province>-<slug>`.}
#'   \item{name_vi, name_en, short_name, aliases}{Vietnamese name, English name
#'     where tagged, diacritic-free short label, and pipe-separated alternates.}
#'   \item{park_key}{Diacritic-free matching key used to join external lists.}
#'   \item{category}{`"industrial_park"`, `"export_processing_zone"`,
#'     `"high_tech_park"`, or `"industrial_cluster"`.}
#'   \item{province_code, province_en}{Current 34-unit assignment.}
#'   \item{former_province_code, former_province_en}{Pre-2025 63-unit assignment.}
#'   \item{commune_code, commune_name}{Current commune holding the park's
#'     representative point.}
#'   \item{status}{`"under_construction"` where tagged, otherwise `"unknown"`.}
#'   \item{area_ha}{Mapped site area in hectares; `NA` for locality records.}
#'   \item{developer}{Operator where tagged.}
#'   \item{geometry_type, location_accuracy, geometry_source}{How the location
#'     was derived: a drawn site polygon, a tagged site point, or the centre of
#'     the reference features naming the park.}
#'   \item{feature_count, osm_refs}{Number of contributing OpenStreetMap
#'     elements and their pipe-separated URLs.}
#'   \item{lon, lat}{Representative point in WGS 84.}
#'   \item{source_url, source_date, verified_on}{Provenance of the record.}
#'   \item{geometry}{Present in [industrial_parks()], absent from
#'     [industrial_park_registry()].}
#' }
#' @source OpenStreetMap contributors, ODbL 1.0,
#' \url{https://www.openstreetmap.org/copyright}; official-register comparison:
#' Foreign Investment Agency, Ministry of Finance, as of 30 September 2025,
#' \url{https://tapchikinhtetaichinh.vn/ca-nuoc-co-478-khu-cong-nghiep-da-di-vao-hoat-dong-voi-ty-le-lap-day-cao-102742.html}.
#' @keywords datasets
NULL
