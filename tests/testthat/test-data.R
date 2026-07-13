test_that("2024 statistical datasets match their geographies", {
  expect_s3_class(province_stats_2024, "data.frame")
  expect_s3_class(province_stats_2024_63, "data.frame")
  expect_equal(nrow(province_stats_2024), 34L)
  expect_equal(nrow(province_stats_2024_63), 63L)
  expect_setequal(province_stats_2024$code, province_info()$code)
  expect_setequal(
    province_stats_2024_63$code,
    province_info(geography = "provinces_63")$code
  )
  expect_false(anyNA(province_stats_2024$population))
  expect_false(anyNA(province_stats_2024$grdp_per_capita_million_vnd))
})

test_that("current statistics use defensible aggregation", {
  lao_cai <- province_stats_2024[province_stats_2024$code == "15", ]
  members <- province_stats_2024_63[province_stats_2024_63$code %in% c("10", "15"), ]
  expect_equal(lao_cai$population, sum(members$population))
  expect_equal(lao_cai$area_km2, sum(members$area_km2))
  expect_equal(
    lao_cai$grdp_per_capita_million_vnd,
    weighted.mean(members$grdp_per_capita_million_vnd, members$population)
  )
})
