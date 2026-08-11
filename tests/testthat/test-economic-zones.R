test_that("economic zones expose legal and spatial metadata", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  skip_if_not_installed("sf")
  x <- economic_zones()
  expect_s3_class(x, "sf")
  expect_equal(nrow(x), 52L)
  expect_equal(sf::st_crs(x), vnmap_crs())
  expect_equal(anyDuplicated(x$id), 0L)
  expect_true(all(c("zone_type", "legal_document", "established_effective_date",
                    "legal_status", "operational_status", "evidence_date",
                    "geometry_available", "legal_evidence", "source_url",
                    "geometry_method") %in% names(x)))
  expect_true(all(is.na(x$source_url) | grepl("^https://", x$source_url)))
  expect_true(all(x$location_accuracy == "province_only"))
  expect_false(any(x$geometry_available))
  expect_true(all(x$legal_status %in% c(
    "established", "candidate_or_count_reconciled")))
  expect_true(all(x$operational_status == "unknown"))
  unsupported <- x$id %in% c("coastal_dung_quat", "epz_tan_thuan",
    "epz_linh_trung_1", "epz_linh_trung_2", "coastal_ninh_co",
    "coastal_south_hai_phong")
  expect_true(all(is.na(x$established_effective_date[unsupported])))
  expect_true(all(sf::st_is_valid(x)))
  expect_false(any(sf::st_is_empty(x)))
})

test_that("legal instruments and baseline claims remain conservative", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  docs_path <- test_path("..", "..", "data-raw",
                         "economic-zone-legal-instruments.csv")
  audit_path <- test_path("..", "..", "data-raw", "economic-zones-audit.csv")
  links_path <- test_path("..", "..", "data-raw", "economic-zone-document-links.csv")
  skip_if_not(file.exists(docs_path) && file.exists(audit_path) && file.exists(links_path),
              "data-raw audit files are not installed")
  docs <- utils::read.csv(docs_path)
  audit <- utils::read.csv(audit_path)
  links <- utils::read.csv(links_path)
  x <- economic_zones(crs = 4326)
  expect_equal(anyDuplicated(docs$document_id), 0L)
  expect_true(all(na.omit(x$legal_document) %in% docs$document_id))
  national_counts <- audit$zone_type %in% c(
    "coastal_economic_zone", "border_gate_economic_zone")
  expect_true(all(is.na(audit$gap[national_counts])))
  expect_true(all(grepl("official_count_only", audit$baseline_status[national_counts])))
  established <- x[x$legal_status == "established", ]
  expect_setequal(established$id, c("coastal_chu_lai", "border_mong_cai",
                                    "htp_hoa_lac", "htp_da_nang"))
  expect_true(all(established$evidence_state ==
                    "row_level_establishment_instrument_verified"))
  expect_setequal(established$id[!is.na(established$established_effective_date)],
                  c("border_mong_cai", "htp_da_nang"))
  expect_setequal(links$zone_id[links$evidence_role == "verified_establishment"],
                  established$id)
  dung <- x[x$id == "coastal_dung_quat", ]
  expect_equal(dung$legal_status, "candidate_or_count_reconciled")
  expect_equal(dung$legal_document, "25/2010/QD-TTg")
  expect_equal(dung$evidence_date, as.Date("2010-03-03"))
  expect_equal(dung$source_date, as.Date("2010-03-03"))
  expect_match(dung$source_url, "docid=93583", fixed = TRUE)
  expect_equal(dung$legal_evidence, "current_operating_regulation_not_establishment")
  expect_true(is.na(dung$established_approval_date))
  expect_true(is.na(dung$established_effective_date))
  dung_doc <- docs[docs$document_id == "25/2010/QD-TTg", ]
  expect_equal(dung_doc$evidence_role, "current_operating_regulation")
  expect_equal(as.Date(dung_doc$document_date), as.Date("2010-03-03"))
  expect_equal(as.Date(dung_doc$verified_effective_date), as.Date("2010-05-01"))
  expect_equal(links$evidence_role[links$zone_id == dung$id],
               "verified_current_operating_regulation")
})

test_that("economic zone filters are consistent and time-aware", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  skip_if_not_installed("sf")
  htp <- economic_zones(type = "national_high_tech_park")
  expect_equal(nrow(htp), 3L)
  expect_true(all(htp$zone_type == "national_high_tech_park"))
  expect_equal(nrow(economic_zones(include = "Hoa Lac Hi-Tech Park")), 1L)
  expect_equal(nrow(economic_zones(province = "Ho Chi Minh City")), 4L)
  expect_equal(nrow(economic_zones(province = "79")), 4L)
  old <- economic_zones(as_of = "2013-01-01", include_unknown = FALSE)
  expect_true(all(old$established_effective_date <= as.Date("2013-01-01")))
  expect_gt(nrow(economic_zones(as_of = "2013-01-01", include_unknown = TRUE)), nrow(old))
  expect_error(economic_zones(type = "industrial_park"), "Unknown")
  expect_error(economic_zones(status = "operational"), "Unknown")
  expect_error(economic_zones(geometry = "polygon"), "No economic zones")
})

test_that("official national catalogue counts and supplied-data filters hold", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  skip_if_not_installed("sf")
  x <- economic_zones(crs = 4326)
  expect_equal(sum(x$zone_type == "coastal_economic_zone"), 20L)
  expect_equal(sum(x$zone_type == "border_gate_economic_zone"), 26L)
  layers <- geom_economic_zones(data = x, type = "national_high_tech_park")
  expect_equal(nrow(layers[[1]][[1]]$data), 3L)
  expect_equal(layers[[1]][[1]]$aes_params$shape, 4)
  alias_layers <- geom_economic_zones(data = x, include = "Hoa Lac Hi-Tech Park")
  expect_equal(nrow(alias_layers[[1]][[1]]$data), 1L)
})

test_that("province fallback warning is explicit", {
  withr::local_options(list(vnmap.suppress_fallback_warning = FALSE))
  skip_if_not_installed("sf")
  expect_warning(economic_zones(type = "coastal_economic_zone"),
                 "associated province only")
})

test_that("supplied data respects geometry, date validation, and warnings", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  skip_if_not_installed("sf")
  x <- economic_zones(crs = 4326)
  expect_error(geom_economic_zones(data = x, geometry = "polygon"),
               "No economic zones")
  expect_error(geom_economic_zones(data = x, as_of = c("2010-01-01", "2011-01-01")),
               "one valid date")
  expect_error(geom_economic_zones(data = x, as_of = "not-a-date"),
               "one valid date")
  withr::local_options(list(vnmap.suppress_fallback_warning = FALSE))
  expect_warning(geom_economic_zones(data = x, type = "national_high_tech_park"),
                 "associated province only")
})

test_that("economic zone layer composes with plot_vnmap", {
  withr::local_options(list(vnmap.suppress_fallback_warning = TRUE))
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  p <- plot_vnmap() + geom_economic_zones(type = "coastal_economic_zone")
  expect_s3_class(p, "ggplot")
})
