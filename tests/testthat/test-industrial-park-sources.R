test_that("source records are conserved and unresolved locations are not invented", {
  x <- industrial_park_sources()
  expect_equal(anyDuplicated(x$source_record_id), 0L)
  expect_equal(nrow(x), 1651L)
  expect_equal(sum(x$source == "Invest Vietnam"), 391L)
  expect_equal(sum(x$source == "KCN-KKT discovery (unverified)"), 1260L)
  unresolved <- industrial_park_sources(mapped = FALSE)
  expect_true(all(is.na(unresolved$longitude) & is.na(unresolved$latitude)))
  expect_true(all(is.na(unresolved$map_id)))
  linked <- industrial_park_sources(mapped = TRUE)
  expect_true(all(is.finite(linked$longitude) & is.finite(linked$latitude)))
  expect_equal(nrow(unresolved) + nrow(linked), nrow(x))
  coverage <- industrial_park_source_coverage()
  expect_equal(coverage$source_records, coverage$linked_records + coverage$unresolved_records)
  expect_true(all(coverage$distinct_linked_map_sites <= coverage$linked_records))
  expect_error(industrial_park_sources(mapped = NA), "mapped")
  expect_error(industrial_park_sources(mapped = 1), "mapped")
  expect_error(industrial_park_sources(source = "invented"), "Unknown source")
  # A highway from Hanoi to Hoa Binh does not place Binh Phu in Hanoi.
  road_description <- x[x$source_url == "https://investvietnam.gov.vn/vi/kcn.pd/khu-cong-nghiep-binh-phu.html", ]
  expect_false(any(road_description$coordinate_available))
})

test_that("linked source coordinates come from the indicated mapped site", {
  skip_if_not_installed("sf")
  x <- industrial_park_sources(mapped = TRUE)
  parks <- industrial_parks(category = NULL, crs = 4326)
  expect_true(all(x$map_id %in% parks$id))
  expect_true(all(x$coordinate_source_url == parks$source_url[match(x$map_id, parks$id)]))
  points <- sf::st_as_sf(x, coords = c("longitude", "latitude"), crs = 4326)
  distance <- sf::st_distance(sf::st_transform(points, 3405),
    sf::st_transform(parks[match(x$map_id, parks$id), ], 3405), by_element = TRUE)
  expect_true(all(as.numeric(distance) < 5))
})

test_that("land-use tags do not assert operational status", {
  skip_if_not_installed("sf")
  parks <- industrial_parks(category = NULL)
  expect_false(any(parks$status[parks$attribute_source == "osm"] == "operational"))
})
