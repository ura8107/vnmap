test_that("current communes are available with explicit vintage metadata", {
  skip_if_not_installed("sf")
  x <- vn_map("communes")
  expect_s3_class(x, "sf")
  expect_equal(nrow(x), 3321)
  expect_equal(sf::st_crs(x)$epsg, 3405)
  expect_equal(anyDuplicated(x$code), 0L)
  expect_true(all(c("valid_from", "valid_to", "geography_vintage",
                    "source_url", "snapshot_date", "observed_on",
                    "geometry_accuracy") %in% names(x)))
  expect_true(all(is.na(x$valid_from)))
  expect_true(all(is.na(x$valid_to)))
  expect_true(all(sf::st_is_valid(x)))
  expect_false(any(sf::st_is_empty(x)))
})

test_that("current communes use current province normalization", {
  skip_if_not_installed("sf")
  a <- vn_map("communes", province = "Ha Noi")
  b <- vn_map("communes", province = "01")
  expect_equal(a$code, b$code)
  expect_equal(nrow(a), 126)
  expect_error(vn_map("communes", region = "RRD"), "region")
  expect_error(vn_map("communes", province = "Atlantis"), "Unknown province")
})

test_that("current provinces use and contain the exact commune source", {
  skip_if_not_installed("sf")
  communes <- vn_map("communes", crs = 3405)
  provinces <- vn_map(crs = 3405)
  expect_identical(unique(communes$geography_vintage), unique(provinces$geography_vintage))
  reps <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(communes)))
  within <- sf::st_within(reps, sf::st_geometry(provinces))
  idx <- vapply(within, function(i) if (length(i) == 1L) i else NA_integer_, integer(1))
  expect_false(anyNA(idx))
  expect_equal(provinces$code[idx], communes$province_code)

  pairs <- combn(nrow(provinces), 2L)
  overlap_m2 <- vapply(seq_len(ncol(pairs)), function(j) {
    overlap <- suppressWarnings(sf::st_intersection(
      sf::st_geometry(provinces)[pairs[1L, j]],
      sf::st_geometry(provinces)[pairs[2L, j]]
    ))
    sum(as.numeric(sf::st_area(overlap)))
  }, numeric(1))
  expect_lt(max(overlap_m2), 1000)
})

test_that("partial-transfer notes tolerate all observed whitespace variants", {
  notes <- c("Nhập một phần xã A", "Nhập một  phần xã A",
             "Nhập một\tphần xã A", "Nhập 1 phần xã A", "Nhập 01   phần xã A")
  expect_true(all(vnmap:::.is_partial_transfer(notes)))
  expect_false(any(vnmap:::.is_partial_transfer(c("Nhập toàn bộ xã A", NA))))
})

test_that("crosswalk requires a source workbook and filters fail clearly", {
  expect_error(administrative_crosswalk(tempfile(fileext = ".xlsx")), "does not exist")
  x <- data.frame(current_code = "00004", current_name = "Ba Dinh",
                  former_code = "00013", former_name = "Quan Thanh",
                  current_province_code = "01", former_province_code = "01")
  expect_error(vnmap:::.filter_administrative_crosswalk(x, province = "Atlantis"),
               "Unknown current or historical province")
  expect_error(vnmap:::.filter_administrative_crosswalk(x, current = "99999"),
               "No administrative")
})

test_that("crosswalk schema rejects malformed codes", {
  valid <- data.frame(
    current_province = "Ha Noi (01)", current_name = "Ba Dinh",
    current_code = "00004", former_name = "Quan Thanh",
    former_code = "00013", change_note = "Nhap toan bo",
    former_district = "Ba Dinh", former_province = "Ha Noi (01)"
  )
  expect_equal(vnmap:::.validate_crosswalk_codes(valid), list("01", "01"))

  bad_commune <- valid
  bad_commune$current_code <- "4A"
  expect_error(vnmap:::.validate_crosswalk_codes(bad_commune), "invalid current_code")

  bad_province <- valid
  bad_province$former_province <- "Ha Noi"
  expect_error(vnmap:::.validate_crosswalk_codes(bad_province), "province codes")

  expect_error(vnmap:::.validate_crosswalk_codes(valid[FALSE, ]), "no administrative")
})

test_that("failed crosswalk downloads remove partial files", {
  dest <- tempfile(fileext = ".xlsx")
  testthat::local_mocked_bindings(
    .crosswalk_url = "file:///this/path/does/not/exist.xlsx",
    .package = "vnmap"
  )
  expect_error(download_administrative_crosswalk(dest), "download failed")
  expect_false(file.exists(dest))
})
