#' Vietnamese industrial parks with mapped locations
#'
#' A conservative spatial snapshot of established industrial parks in Viet Nam.
#' Records are included only when a redistributable mapped location can be
#' identified. Boundaries and points come from OpenStreetMap and are linked to
#' both the current 34-unit and former 63-unit provincial geographies.
#'
#' @name industrial_parks_data
#' @format An internal `sf` object with `id`, `name_vi`, `name_en`, `aliases`,
#' `province_code`, `province_en`, `former_province_code`, `status`, `area_ha`,
#' `developer`, `geometry_type`, `location_accuracy`, `source_url`,
#' `source_date`, `verified_on`, and `geometry`.
#' @source OpenStreetMap contributors, ODbL 1.0,
#' \url{https://www.openstreetmap.org/copyright}; official-list comparison:
#' Foreign Investment Agency InvestVietnam,
#' \url{https://www.investvietnam.gov.vn/en/industrial-zones.pl.html}.
#' @keywords datasets
NULL
