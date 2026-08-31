test_that("the registry loads without sf and keeps a stable contract", {
  registry <- industrial_park_registry()
  expect_s3_class(registry, "data.frame")
  expect_false(inherits(registry, "sf"))
  expect_gt(nrow(registry), 250L)
  expect_identical(anyDuplicated(registry$id), 0L)
  expect_true(all(c("id", "name_vi", "short_name", "park_key", "category",
                    "province_code", "former_province_code", "commune_code",
                    "status", "area_ha", "location_accuracy", "geometry_source",
                    "feature_count", "osm_refs", "lon", "lat", "source_url",
                    "verified_on") %in% names(registry)))
  expect_false(anyNA(registry$province_code))
  expect_false(anyNA(registry$park_key))
  expect_true(all(registry$province_code %in% province_info()$code))
  expect_true(all(registry$former_province_code %in%
                    province_info(geography = "provinces_63")$code))
})

test_that("registry coordinates sit inside Viet Nam", {
  registry <- industrial_park_registry()
  expect_true(all(registry$lon > 102 & registry$lon < 110))
  expect_true(all(registry$lat > 8 & registry$lat < 24))
})

test_that("locality records carry a reference point and no mapped area", {
  registry <- industrial_park_registry()
  locality <- registry[registry$location_accuracy == "locality", ]
  expect_gt(nrow(locality), 0L)
  expect_true(all(is.na(locality$area_ha)))
  expect_true(all(locality$geometry_type == "point"))
  sites <- registry[registry$location_accuracy == "site", ]
  expect_true(all(sites$area_ha > 0))
  expect_true(all(sites$geometry_source == "osm_site_polygon"))
})

test_that("registry filters validate their arguments", {
  by_name <- industrial_park_registry(province = "Đồng Nai")
  by_code <- industrial_park_registry(province = "75")
  expect_setequal(by_name$id, by_code$id)
  expect_true(all(industrial_park_registry(accuracy = "site")$area_ha > 0))
  expect_equal(
    nrow(industrial_park_registry(include = by_name$id[1])), 1L
  )
  expect_error(industrial_park_registry(province = "Atlantis"), "Unknown province")
  expect_error(industrial_park_registry(status = "planned"), "Unknown industrial park status")
  expect_error(industrial_park_registry(category = "farm"), "Unknown industrial park category")
  expect_error(industrial_park_registry(accuracy = "exact"), "Unknown location accuracy")
})

test_that("the registry and the spatial layer describe the same parks", {
  skip_if_not_installed("sf")
  registry <- industrial_park_registry()
  parks <- industrial_parks()
  expect_setequal(registry$id, parks$id)
  expect_setequal(names(registry), setdiff(names(parks), "geometry"))
})

test_that("provincial coverage covers every current unit", {
  coverage <- industrial_park_coverage()
  info <- province_info()
  expect_setequal(coverage$province_code, info$code)
  expect_equal(sum(coverage$parks), nrow(industrial_park_registry()))
  expect_true(all(coverage$locality_only ==
                    coverage$parks - coverage$with_boundary))
  expect_true(all(coverage$mapped_area_ha >= 0))
})

test_that("national coverage is measured against a cited official baseline", {
  national <- industrial_park_coverage("national")
  expect_true(all(c("metric", "value", "mapped", "coverage", "source_url") %in%
                    names(national)))
  established <- national[national$metric == "established_industrial_parks", ]
  expect_equal(nrow(established), 1L)
  expect_equal(established$value, 478)
  expect_lt(established$mapped, established$value)
  expect_true(all(grepl("^https://", national$source_url)))
  expect_error(industrial_park_coverage("global"), "arg")
})
