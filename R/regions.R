.vn_regions <- function(geography) {
  file <- system.file("extdata", "regions.rds", package = "vnmap")
  if (!nzchar(file)) stop("Bundled region data could not be found.", call. = FALSE)
  readRDS(file)[[geography]]
}

# Resolve region codes or English region names to the unit codes they contain.
.region_filter <- function(region, geography) {
  reg <- .vn_regions(geography)
  key <- function(z) toupper(gsub("[^A-Za-z]", "", as.character(z)))
  want <- key(region)
  hit <- key(reg$region_code) %in% want | key(reg$region_en) %in% want
  matched <- want %in% key(reg$region_code) | want %in% key(reg$region_en)
  if (!all(matched)) {
    bad <- unique(as.character(region)[!matched])
    stop("Unknown region: ", paste(bad, collapse = ", "), call. = FALSE)
  }
  reg$code[hit]
}

#' Socio-economic region of Vietnamese provincial units
#'
#' Returns the socio-economic region that each provincial-level unit belongs
#' to. Regions follow the six-region scheme published by the General Statistics
#' Office of Viet Nam.
#'
#' @param x Optional names or codes accepted by [province_code()]. When omitted,
#'   every unit is returned in ascending code order.
#' @param geography Either `"provinces"` for the current 34-unit geography or
#'   `"provinces_63"` for the historical 63-unit geography.
#'
#' @return A character vector of English region names. When `x` is omitted the
#'   vector is named by administrative code.
#'
#' @details The six regions are the Red River Delta (`RRD`), Northern Midlands
#'   and Mountains (`NMM`), North Central and Central Coast (`NCC`), Central
#'   Highlands (`CH`), Southeast (`SE`), and Mekong River Delta (`MRD`).
#'
#'   Region assignments for the 63-unit geography are the official ones.
#'   Assignments for the 34 current units are derived: each 2025 unit is placed
#'   in the region holding the largest share of its 2024 population among the
#'   former units it absorbed. Use [province_info()] to obtain the region code
#'   and Vietnamese region name alongside the English name.
#'
#' @seealso [province_info()], [vn_map()], [plot_vnmap()]
#'
#' @examples
#' province_region(c("HCMC", "Can Tho"))
#' province_region("Bac Giang", geography = "provinces_63")
#' head(province_region())
#' @export
province_region <- function(x = NULL, geography = c("provinces", "provinces_63")) {
  geography <- match.arg(geography)
  reg <- .vn_regions(geography)
  if (is.null(x)) return(stats::setNames(reg$region_en, reg$code))
  codes <- province_code(x, geography)
  unname(reg$region_en[match(codes, reg$code)])
}
