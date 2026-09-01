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

test_that("categories separate the legal designations", {
  skip_if_not_installed("sf")
  register <- industrial_parks()
  expect_setequal(unique(register$category),
                  c("industrial_park", "export_processing_zone"))
  every <- industrial_parks(category = NULL)
  expect_gt(nrow(every), nrow(register))
  expect_true(all(c("hi_tech_park", "industrial_cluster") %in% every$category))
  expect_error(industrial_parks(category = "science_park"),
               "Unknown industrial park category")
})

test_that("merged records keep their component ids", {
  skip_if_not_installed("sf")
  parks <- industrial_parks(category = NULL)
  expect_true(all(parks$part_count >= 1L))
  merged <- parks[parks$part_count > 1L, ]
  expect_gt(nrow(merged), 0L)
  expect_true(all(lengths(strsplit(merged$osm_ids, "|", fixed = TRUE)) ==
                    merged$part_count))
  expect_true(all(vapply(seq_len(nrow(merged)), function(i) {
    merged$id[i] %in% strsplit(merged$osm_ids[i], "|", fixed = TRUE)[[1]]
  }, logical(1))))
})

test_that("the template describes the columns a user may write", {
  skip_if_not_installed("sf")
  template <- industrial_parks_template(province = "Da Nang")
  expect_true(all(c("id", "name_vi", "status", "area_ha", "occupancy_rate",
                    "notes", "province_code", "longitude", "latitude") %in%
                    names(template)))
  expect_identical(nrow(template), nrow(industrial_parks(province = "Da Nang")))
  blank <- industrial_parks_template(province = "Da Nang", blank = TRUE)
  expect_true(all(is.na(blank$name_vi)))
  expect_identical(blank$id, template$id)

  path <- tempfile(fileext = ".csv")
  industrial_parks_template(path, province = "Da Nang")
  expect_true(file.exists(path))
  expect_identical(nrow(utils::read.csv(path)), nrow(template))
})

test_that("user attributes override bundled values", {
  skip_if_not_installed("sf")
  parks <- industrial_parks(province = "Da Nang")
  edit <- data.frame(id = parks$id[1], status = "under_construction",
                     occupancy_rate = 72.5, notes = "field visit",
                     stringsAsFactors = FALSE)
  updated <- industrial_parks(province = "Da Nang", attributes = edit)
  row <- updated[updated$id == parks$id[1], ]
  expect_identical(nrow(updated), nrow(parks))
  expect_identical(row$status, "under_construction")
  expect_identical(row$occupancy_rate, 72.5)
  expect_identical(row$notes, "field visit")
  expect_identical(row$attribute_source, "user")
  expect_true(all(updated$attribute_source[updated$id != parks$id[1]] == "osm"))

  untouched <- industrial_parks_template(province = "Da Nang", blank = TRUE)
  expect_setequal(industrial_parks(province = "Da Nang",
                                   attributes = untouched)$name_vi,
                  parks$name_vi)
})

test_that("user attributes add parks the snapshot does not carry", {
  skip_if_not_installed("sf")
  before <- industrial_parks(province = "Da Nang")
  added <- data.frame(id = "user_demo_1", name_vi = "Khu cong nghiep Demo",
                      province_code = "48", area_ha = 120,
                      longitude = 108.15, latitude = 16.05,
                      stringsAsFactors = FALSE)
  after <- industrial_parks(province = "Da Nang", attributes = added)
  expect_identical(nrow(after), nrow(before) + 1L)
  new <- after[after$id == "user_demo_1", ]
  expect_identical(new$source, "user")
  expect_identical(new$location_accuracy, "user_supplied")
  expect_identical(new$province_en, "Da Nang")
  expect_identical(new$category, "industrial_park")

  expect_error(industrial_parks(attributes = added[c("id", "name_vi")]),
               "New parks need")
  expect_error(industrial_parks(attributes = data.frame(id = "x", province_en = "y")),
               "not user-writable")
  expect_error(industrial_parks(attributes = data.frame(name_vi = "x")),
               "needs an `id` column")
  expect_error(industrial_parks(attributes = data.frame(id = c("a", "a"))),
               "repeats these ids")
})

test_that("parks round-trip through the exported formats", {
  skip_if_not_installed("sf")
  parks <- industrial_parks(province = "Da Nang")
  csv <- tempfile(fileext = ".csv")
  write_industrial_parks(parks, csv)
  flat <- utils::read.csv(csv)
  expect_identical(nrow(flat), nrow(parks))
  expect_true(all(c("longitude", "latitude") %in% names(flat)))

  geojson <- tempfile(fileext = ".geojson")
  write_industrial_parks(parks, geojson)
  expect_identical(nrow(sf::st_read(geojson, quiet = TRUE)), nrow(parks))

  expect_error(write_industrial_parks(data.frame(x = 1), csv), "sf object")
})
