test_that("province_region resolves names and codes", {
  expect_equal(unname(province_region(c("HCMC", "Can Tho"))), c("Southeast", "Mekong River Delta"))
  expect_equal(
    province_region("Bac Giang", geography = "provinces_63"),
    "Northern Midlands and Mountains"
  )
  expect_error(province_region("Atlantis"), "Unknown")
})

test_that("region tables cover every unit", {
  expect_length(province_region(), 34L)
  expect_length(province_region(geography = "provinces_63"), 63L)
  expect_false(anyNA(province_region()))
  expect_false(anyNA(province_region(geography = "provinces_63")))
  expect_setequal(
    unique(province_region(geography = "provinces_63")),
    c("Red River Delta", "Northern Midlands and Mountains",
      "North Central and Central Coast", "Central Highlands",
      "Southeast", "Mekong River Delta")
  )
})

test_that("province_info exposes region columns without geometry", {
  info <- province_info()
  expect_false(inherits(info, "sf"))
  expect_true(all(c("region_code", "region_vi", "region_en") %in% names(info)))
  expect_false(anyNA(info$region_code))
  expect_equal(province_info("HCMC")$region_code, "SE")
})

test_that("region filtering selects whole regions", {
  skip_if_not_installed("sf")
  delta <- vn_map(region = "MRD")
  expect_equal(nrow(delta), sum(province_region() == "Mekong River Delta"))
  # include and region are additive
  combined <- vn_map(region = "MRD", include = "Ha Noi")
  expect_equal(nrow(combined), nrow(delta) + 1L)
  expect_error(vn_map(region = "Nowhere"), "Unknown region")
})

test_that("plot accepts region and insets", {
  skip_if_not_installed("sf")
  expect_s3_class(plot_vnmap(region = "SE"), "ggplot")
  expect_s3_class(plot_vnmap(insets = TRUE), "ggplot")
  expect_s3_class(plot_vnmap(insets = c("Ha Noi", "HCMC")), "ggplot")
})

test_that("lower-level geographies error clearly when not bundled", {
  skip_if_not_installed("sf")
  if (!nzchar(system.file("extdata", "districts_63.rds", package = "vnmap"))) {
    expect_error(vn_map("districts_63"), "build_adm2")
  }
  if (!nzchar(system.file("extdata", "communes_63.rds", package = "vnmap"))) {
    expect_error(vn_map("communes_63"), "build_adm3")
    expect_error(vn_map("communes_63", province = "Ha Noi"), "build_adm3")
  }
})

test_that("province filter is confined to lower-level geographies", {
  skip_if_not_installed("sf")
  expect_error(vn_map(province = "Ha Noi"), "lower-level")
  expect_error(vn_map("provinces_63", province = "Ha Noi"), "lower-level")
})
