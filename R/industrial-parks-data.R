#' Vietnamese industrial parks with mapped locations
#'
#' A conservative spatial snapshot of Vietnamese industrial parks, export
#' processing zones, hi-tech parks and industrial clusters. Records are
#' included only when a redistributable mapped location can be identified, so
#' the layer is a mapped subset of the national register rather than the
#' register itself: `data-raw/industrial-parks-audit.csv` reports mapped
#' coverage against the official count of established parks, and unmapped
#' parks are left out rather than being placed at a province centroid.
#'
#' Sites mapped in several pieces - phases, expansions, a site split by a road
#' - are merged into one record; `part_count` and `osm_ids` record how many
#' OpenStreetMap features contributed and which ones. Boundaries and points are
#' linked to both the current 34-unit and former 63-unit provincial
#' geographies.
#'
#' `category` separates the legal designations, which are not interchangeable:
#' `"industrial_park"` (khu cong nghiep) and `"export_processing_zone"`
#' (khu che xuat) are both counted in the national industrial-park register,
#' while `"hi_tech_park"` (khu cong nghe cao) and `"industrial_cluster"`
#' (cum cong nghiep, a provincial tier) are not.
#'
#' @name industrial_parks_data
#' @format An internal `sf` object with `id`, `name_vi`, `name_en`, `aliases`,
#' `category`, `province_code`, `province_en`, `former_province_code`,
#' `status`, `area_ha`, `developer`, `website`, `geometry_type`,
#' `location_accuracy`, `part_count`, `osm_ids`, `source`, `source_url`,
#' `verified_on`, `attribute_source`, and `geometry`.
#' @source OpenStreetMap contributors, ODbL 1.0,
#' \url{https://www.openstreetmap.org/copyright}. The official baseline used
#' for the coverage audit is the Foreign Investment Agency (Ministry of
#' Finance) national industrial-park report of 16 November 2025, recorded with
#' its source URL in `data-raw/industrial-park-baseline.csv`.
#' @keywords datasets
NULL
