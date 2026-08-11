test_that("infrastructure snapshot has a stable research contract", {
  skip_if_not_installed("sf")
  x <- infrastructure(crs = 4326)
  expect_s3_class(x, "sf")
  expect_equal(nrow(x), 34191L)
  expect_identical(anyDuplicated(x$id), 0L)
  expect_true(all(c("expressway", "national_highway", "railway") %in% x$infrastructure_type))
  expect_true(all(c("valid_from", "valid_to", "snapshot_date", "observed_on",
                    "source_authority", "verification_status", "location_accuracy",
                    "service_type", "status_source", "aliases", "source_ids",
                    "source_geometry_method", "country_relation") %in% names(x)))
  expect_true(all(is.na(x$valid_from)))
  expect_false(anyNA(x$status))
  expect_true(all(x$status %in% c("planned", "under_construction", "disused", "abandoned", "unknown")))
  expect_false(any(x$infrastructure_type %in% c("airport", "seaport", "border_gate")))
  expect_equal(sum(x$infrastructure_type == "aerodrome"), 42L)
  expect_equal(sum(x$infrastructure_type == "port"), 80L)
  expect_equal(sum(x$infrastructure_type == "border_control"), 32L)
  expect_equal(sum(x$infrastructure_type == "expressway"), 7650L)
  expect_equal(sum(x$infrastructure_type == "national_highway"), 22648L)
  expect_equal(sum(x$infrastructure_type == "railway"), 3739L)
  facilities <- x[x$geometry_type == "point", ]
  expect_true(all(facilities$snapshot_date == as.Date("2026-07-09")))
  expect_true(all(facilities$observed_on == as.Date("2026-08-11")))
  expect_true(all(facilities$location_accuracy %in% c(
    "osm_node", "osm_center", "bounds_midpoint")))
  expect_true(all(facilities$status == "unknown" |
                    facilities$status_source != "none"))
})

test_that("infrastructure filters include networks", {
  skip_if_not_installed("sf")
  airports <- infrastructure(type = "aerodrome")
  expect_true(all(airports$infrastructure_type == "aerodrome"))
  expect_true(all(airports$service_type %in% c("commercial_service_candidate", "service_not_established")))
  expect_gt(nrow(infrastructure(type = "port", class = "fishing_port")), 0L)
  expect_gt(nrow(infrastructure(type = "railway", service = "service=yard")), 0L)
  expect_gt(nrow(infrastructure(province = "Ho Chi Minh")), 0L)
  expect_error(infrastructure(type = "airport"), "Unknown infrastructure type")
  expect_error(infrastructure(class = "definitely_not_a_class"), "Unknown infrastructure class")
  expect_error(infrastructure(service = "definitely_not_a_service"), "Unknown infrastructure service")
  expect_error(infrastructure(status = "closed"), "Unknown infrastructure status")
  expect_gt(nrow(infrastructure(type = "railway")), 0L)
  expect_error(infrastructure(province = "Atlantis"), "Unknown province")
})

test_that("railway service and usage are not mislabeled as main line", {
  skip_if_not_installed("sf")
  rail <- infrastructure(type = "railway", crs = 4326)
  expect_true(all(rail$infrastructure_class[rail$railway_service %in% "yard"] == "rail_yard"))
  expect_true(all(rail$infrastructure_class[rail$railway_service %in% "siding"] == "rail_siding"))
  expect_true(all(rail$infrastructure_class[rail$railway_service %in% "spur"] == "rail_spur"))
  industrial <- rail$railway_usage %in% "industrial"
  expect_false(any(rail$infrastructure_class[industrial] == "main_line"))
  expect_true(all(rail$infrastructure_class[industrial & is.na(rail$railway_service)] ==
                    "industrial_line"))
  expect_true(all(rail$railway_usage[rail$infrastructure_class == "main_line"] == "main"))
  expect_false(anyNA(rail$infrastructure_class))
})

test_that("network is clipped and carries no fabricated scalar province", {
  skip_if_not_installed("sf")
  network <- infrastructure(geometry = "line", crs = 3405)
  country <- sf::st_make_valid(sf::st_transform(
    sf::st_sf(geometry = sf::st_union(sf::st_geometry(vn_map(crs = 4326)))), 3405))
  expect_true(all(lengths(sf::st_intersects(network, country)) > 0L))
  expect_true(all(network$distance_to_country_m == 0))
  expect_true(all(is.na(network$province_code)))
  expect_true(all(network$province_assignment_method %in%
                    c("polygon_intersection", "no_polygon_intersection")))
  ids <- network$id[c(1L, nrow(network))]
  expect_equal(sort(infrastructure(include = ids)$id), sort(ids))
})

test_that("near-boundary point province assignment remains queryable", {
  skip_if_not_installed("sf")
  near <- infrastructure(type = "aerodrome", include = "Sân bay quốc tế Cam Ranh")
  expect_equal(near$country_relation, "within_15km_of_generalized_boundary")
  by_province <- infrastructure(type = "aerodrome", province = near$province_code)
  expect_true(near$id %in% by_province$id)
})

test_that("facilities expose generalized-boundary proximity honestly", {
  skip_if_not_installed("sf")
  x <- infrastructure(crs = 4326)
  country <- sf::st_union(sf::st_geometry(vn_map(crs = 4326)))
  expect_true(all(sf::st_is_valid(x)))
  expect_false(any(sf::st_is_empty(x)))
  facilities <- x[x$geometry_type == "point", ]
  expect_true(all(facilities$distance_to_country_m <= 15000))
  expect_true(all(facilities$country_relation %in% c(
    "inside_generalized_boundary", "within_15km_of_generalized_boundary")))
  expect_true(all(facilities$province_code %in% province_info()$code))
  expect_true(all(is.na(x$province_code[x$geometry_type == "line"])))
})

test_that("entity reconciliation retains aliases without double counting", {
  skip_if_not_installed("sf")
  long_thanh <- infrastructure(type = "aerodrome", include = "Phi trường Long Thành")
  expect_equal(nrow(long_thanh), 1L)
  expect_match(long_thanh$aliases, "Phi trường Long Thành", fixed = TRUE)
  ly_van <- infrastructure(type = "border_control", include = "Đồn Biên phòng cửa khẩu Lý Vạn")
  expect_equal(nrow(ly_van), 1L)
  expect_match(ly_van$facility_roles, "border_post", fixed = TRUE)
})

test_that("infrastructure geom handles mixed point and line data", {
  skip_if_not_installed("sf")
  mixed <- sf::st_sf(id = c("p", "l"), geometry = sf::st_sfc(
    sf::st_point(c(106, 16)),
    sf::st_linestring(matrix(c(105, 15, 106, 16), ncol = 2, byrow = TRUE)),
    crs = 4326))
  layers <- geom_infrastructure(data = mixed)
  expect_length(layers, 2L)
  expect_s3_class(plot_vnmap() + layers, "ggplot")
  expect_error(geom_infrastructure(data = data.frame(x = 1)), "sf object")
  expect_length(geom_infrastructure(data = mixed, geometry = "point"), 1L)
})
