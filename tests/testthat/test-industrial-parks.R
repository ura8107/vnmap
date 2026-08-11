test_that("industrial park data has a stable public contract", {
  skip_if_not_installed("sf")
  parks <- industrial_parks()
  expect_s3_class(parks, "sf")
  expect_gt(nrow(parks), 250L)
  expect_identical(anyDuplicated(parks$id), 0L)
  expect_equal(sf::st_crs(parks)$epsg, 3405)
  expect_true(all(c("id", "name_vi", "province_code", "former_province_code",
                    "status", "area_ha", "geometry_type", "location_accuracy",
                    "source_url", "verified_on", "geometry") %in% names(parks)))
})

test_that("industrial park filters normalize province identifiers", {
  skip_if_not_installed("sf")
  by_name <- industrial_parks(province = "Đồng Nai")
  by_ascii <- industrial_parks(province = "Dong Nai")
  by_code <- industrial_parks(province = "75")
  expect_setequal(by_name$id, by_ascii$id)
  expect_setequal(by_name$id, by_code$id)
  expect_true(all(by_name$province_code == "75"))
  expect_error(industrial_parks(province = "Atlantis"), "Unknown province")
  expect_error(industrial_parks(status = "planned"), "Unknown industrial park status")
})

test_that("geometry selection and include filtering work", {
  skip_if_not_installed("sf")
  parks <- industrial_parks()
  expect_equal(nrow(industrial_parks(include = parks$id[1])), 1L)
  polygons <- industrial_parks(geometry = "polygon")
  expect_true(all(tolower(as.character(sf::st_geometry_type(polygons))) %in%
                    c("polygon", "multipolygon")))
  points <- industrial_parks(geometry = "point")
  expect_true(all(sf::st_geometry_type(points) == "POINT"))
})

test_that("park geometries are valid and spatially assigned", {
  skip_if_not_installed("sf")
  parks <- industrial_parks(crs = 4326)
  expect_true(all(sf::st_is_valid(parks)))
  expect_false(any(sf::st_is_empty(parks)))
  expect_false(anyNA(parks$province_code))
  expect_true(all(parks$province_code %in% province_info()$code))
})

test_that("industrial park layers compose with plot_vnmap", {
  skip_if_not_installed("sf")
  layers <- geom_industrial_parks(province = "Dong Nai")
  expect_type(layers, "list")
  expect_true(length(layers) >= 1L)
  expect_s3_class(plot_vnmap() + layers, "ggplot")
  expect_error(geom_industrial_parks(data = data.frame(x = 1)), "sf object")
})
