test_that("both administrative geographies are available", {
  skip_if_not_installed("sf")
  expect_s3_class(vn_map(), "sf")
  expect_equal(nrow(vn_map()), 34)
  expect_equal(nrow(vn_map("provinces_63")), 63)
})

test_that("codes normalize Vietnamese and English names", {
  expect_equal(province_code(c("Đà Nẵng", "Da Nang", "Danang")), rep("48", 3))
  expect_equal(province_code(c("HCMC", "Sài Gòn")), rep("79", 2))
  expect_error(province_code("Atlantis"), "Unknown")
})

test_that("plot data joins by normalized identifiers", {
  skip_if_not_installed("sf")
  d <- data.frame(place = c("Hanoi", "Ca Mau"), value = c(1, 2))
  expect_s3_class(plot_vnmap(data = d, values = "value", id = "place"), "ggplot")
  expect_error(plot_vnmap(data = rbind(d, d[1, ]), values = "value", id = "place"), "duplicate")
})

test_that("metadata is consistent without sf", {
  expect_equal(nrow(province_info()), 34)
  expect_equal(nrow(province_info(geography = "provinces_63")), 63)
  expect_equal(province_info("HCMC")$code, "79")
})

test_that("geometry filtering is consistent", {
  skip_if_not_installed("sf")
  expect_equal(nrow(vn_map(include = c("Hanoi", "24"))), 2)
})

test_that("invalid plotting inputs fail clearly", {
  skip_if_not_installed("sf")
  d <- data.frame(place = "Hanoi", value = 1)
  expect_error(plot_vnmap(data = d, id = "place"), "values")
  expect_error(plot_vnmap(data = d, values = "missing", id = "place"), "values")
  expect_error(plot_vnmap(data = d, values = "value", id = "missing"), "id")
})
