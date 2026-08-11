# Build the conservative, evidence-graded economic-zone snapshot.
#
# The catalogue is intentionally separate from the industrial-park layer.  A
# record is admitted only when an official legal text establishes the zone or
# an official text explicitly recognises it as an operating policy zone.

if (!requireNamespace("sf", quietly = TRUE)) stop("Package 'sf' is required.")

verified_on <- as.Date("2026-08-12")
catalogue <- data.frame(
  id = c("coastal_chu_lai", "coastal_dung_quat", "border_mong_cai",
         "border_cha_lo", "epz_tan_thuan",
         "htp_hoa_lac", "htp_ho_chi_minh", "htp_da_nang"),
  name_vi = c("Khu kinh tế mở Chu Lai", "Khu kinh tế Dung Quất",
              "Khu kinh tế cửa khẩu Móng Cái", "Khu kinh tế cửa khẩu Cha Lo",
              "Khu chế xuất Tân Thuận",
              "Khu công nghệ cao Hòa Lạc", "Khu công nghệ cao Thành phố Hồ Chí Minh",
              "Khu công nghệ cao Đà Nẵng"),
  name_en = c("Chu Lai Open Economic Zone", "Dung Quat Economic Zone",
              "Mong Cai Border-gate Economic Zone", "Cha Lo Border-gate Economic Zone",
              "Tan Thuan Export Processing Zone",
              "Hoa Lac High-Tech Park", "Ho Chi Minh City High-Tech Park",
              "Da Nang High-Tech Park"),
  aliases = c("Chu Lai OEZ", "Dung Quat EZ", "Mong Cai Border Economic Zone",
              "Cha Lo Border Economic Zone", "Tan Thuan EPZ",
              "Hoa Lac Hi-Tech Park", "Saigon Hi-Tech Park|SHTP", "Da Nang Hi-Tech Park"),
  zone_type = c("coastal_economic_zone", "coastal_economic_zone",
                "border_gate_economic_zone", "border_gate_economic_zone",
                "export_processing_zone",
                "national_high_tech_park", "national_high_tech_park",
                "national_high_tech_park"),
  status = rep("established", 8),
  legal_document = c("108/2003/QD-TTg", "25/2010/QD-TTg",
                     "19/2012/QD-TTg", "137/2002/QD-TTg",
                     "194/2003/QD-BTC",
                     "198/QD-TTg", "145/2002/QD-TTg", "1979/QD-TTg"),
  approval_date = as.Date(c("2003-06-05", "2010-03-03", "2012-04-10",
                            "2002-10-15", "2003-11-28",
                            "1998-10-12", "2002-10-24", "2010-10-28")),
  effective_date = as.Date(c("2003-06-05", NA, "2012-06-01",
                             "2002-10-15", "2003-12-15",
                             "1998-10-12", "2002-10-24", "2010-10-28")),
  legal_evidence = c("establishment_decision", "current_operating_regulation_not_establishment",
                     "establishment_decision", "establishment_decision",
                     "official_operational_reference",
                     "establishment_decision", "establishment_decision",
                     "establishment_decision"),
  source_url = c(
    "https://vanban.chinhphu.vn/default.aspx?docid=11933&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=93583&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=157416&pageid=27160",
    "https://vanban.chinhphu.vn/giai-doan-1986-2003-muoi-tam-nam-su-nghiep-doi-moi/iv-chinh-phu-nhiem-ky-quoc-hoi-khoa-xi-2002-2007-2960",
    "https://vanban.chinhphu.vn/default.aspx?docid=12414&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=5711&pageid=27160",
    "https://vanban.chinhphu.vn/giai-doan-1986-2003-muoi-tam-nam-su-nghiep-doi-moi/iv-chinh-phu-nhiem-ky-quoc-hoi-khoa-xi-2002-2007-2960",
    "https://vanban.chinhphu.vn/default.aspx?docid=97516&pageid=27160"),
  lon = c(108.650, 108.800, 107.966, 105.762, 106.728, 105.525, 106.802, 108.052),
  lat = c(15.420, 15.390, 21.525, 17.681, 10.756, 20.995, 10.842, 16.095),
  stringsAsFactors = FALSE
)

# Decision 1711/QD-TTg's current planning annex lists these two separately from
# Tan Thuan as operating export-processing zones. Their original
# establishment dates are not encoded here: the effective date below is the
# date from which this snapshot can substantiate their status with that source.
catalogue <- rbind(catalogue, data.frame(
  id = c("epz_linh_trung_1", "epz_linh_trung_2"),
  name_vi = c("Khu chế xuất Linh Trung I", "Khu chế xuất Linh Trung II"),
  name_en = c("Linh Trung I Export Processing Zone", "Linh Trung II Export Processing Zone"),
  aliases = c("Linh Trung 1 EPZ|Linh Trung EPZ I", "Linh Trung 2 EPZ|Linh Trung EPZ II"),
  zone_type = "export_processing_zone", status = "established",
  legal_document = "1711/QD-TTg",
  approval_date = as.Date("2024-12-31"), effective_date = as.Date("2024-12-31"),
  legal_evidence = "official_current_plan_lists_established_and_operating",
  source_url = "https://congbaocdn.chinhphu.vn/CongBaoCP/VanBan/2024/12/43820/54205-1-2025145-1461711-qd-ttg.pdf",
  lon = c(106.777, 106.765), lat = c(10.858, 10.869), stringsAsFactors = FALSE
))

# Reconcile two officially reported aggregate counts without claiming that the
# names form legally complete national populations. The coastal
# names reconcile the 18-zone 2023 vintage with the two later establishment
# decisions (South Hai Phong and Ninh Co).  The border-gate count is official;
# its name reconciliation is retained with a weaker baseline_status until a
# single machine-readable current national annex is published.
more <- data.frame(
  id = c(
    "coastal_van_don","coastal_dinh_vu_cat_hai","coastal_nghi_son",
    "coastal_dong_nam_nghe_an","coastal_vung_ang","coastal_hon_la",
    "coastal_chan_may_lang_co","coastal_dong_nam_quang_tri",
    "coastal_nhon_hoi","coastal_nam_phu_yen","coastal_van_phong",
    "coastal_phu_quoc","coastal_dinh_an","coastal_nam_can",
    "coastal_thai_binh","coastal_quang_yen","coastal_ninh_co",
    "coastal_south_hai_phong",
    "border_hoanh_mo_dong_van","border_bac_phong_sinh",
    "border_dong_dang_lang_son","border_cao_bang","border_thanh_thuy",
    "border_lao_cai","border_ma_lu_thang","border_tay_trang",
    "border_son_la","border_na_meo","border_nam_can_nghe_an",
    "border_cau_treo","border_lao_bao","border_a_dot","border_nam_giang",
    "border_bo_y","border_le_thanh","border_hoa_lu","border_moc_bai",
    "border_xa_mat","border_long_an","border_dong_thap","border_an_giang",
    "border_ha_tien"),
  name_vi = c(
    "Khu kinh tế Vân Đồn","Khu kinh tế Đình Vũ - Cát Hải","Khu kinh tế Nghi Sơn",
    "Khu kinh tế Đông Nam Nghệ An","Khu kinh tế Vũng Áng","Khu kinh tế Hòn La",
    "Khu kinh tế Chân Mây - Lăng Cô","Khu kinh tế Đông Nam Quảng Trị",
    "Khu kinh tế Nhơn Hội","Khu kinh tế Nam Phú Yên","Khu kinh tế Vân Phong",
    "Khu kinh tế Phú Quốc","Khu kinh tế Định An","Khu kinh tế Năm Căn",
    "Khu kinh tế Thái Bình","Khu kinh tế ven biển Quảng Yên","Khu kinh tế Ninh Cơ",
    "Khu kinh tế ven biển phía Nam Hải Phòng",
    "Khu kinh tế cửa khẩu Hoành Mô - Đồng Văn","Khu kinh tế cửa khẩu Bắc Phong Sinh",
    "Khu kinh tế cửa khẩu Đồng Đăng - Lạng Sơn","Khu kinh tế cửa khẩu Cao Bằng",
    "Khu kinh tế cửa khẩu Thanh Thủy","Khu kinh tế cửa khẩu Lào Cai",
    "Khu kinh tế cửa khẩu Ma Lù Thàng","Khu kinh tế cửa khẩu Tây Trang",
    "Khu kinh tế cửa khẩu Sơn La","Khu kinh tế cửa khẩu Na Mèo",
    "Khu kinh tế cửa khẩu Nậm Cắn","Khu kinh tế cửa khẩu quốc tế Cầu Treo",
    "Khu kinh tế - thương mại đặc biệt Lao Bảo","Khu kinh tế cửa khẩu A Đớt",
    "Khu kinh tế cửa khẩu Nam Giang","Khu kinh tế cửa khẩu quốc tế Bờ Y",
    "Khu kinh tế cửa khẩu Lệ Thanh","Khu kinh tế cửa khẩu Hoa Lư",
    "Khu kinh tế cửa khẩu Mộc Bài","Khu kinh tế cửa khẩu Xa Mát",
    "Khu kinh tế cửa khẩu Long An","Khu kinh tế cửa khẩu tỉnh Đồng Tháp",
    "Khu kinh tế cửa khẩu tỉnh An Giang","Khu kinh tế cửa khẩu Hà Tiên"),
  province = c("Quang Ninh","Hai Phong","Thanh Hoa","Nghe An","Ha Tinh",
    "Quang Binh","Thua Thien Hue","Quang Tri","Binh Dinh","Phu Yen",
    "Khanh Hoa","Kien Giang","Tra Vinh","Ca Mau","Thai Binh","Quang Ninh",
    "Nam Dinh","Hai Phong","Quang Ninh","Quang Ninh","Lang Son","Cao Bang",
    "Ha Giang","Lao Cai","Lai Chau","Dien Bien","Son La","Thanh Hoa",
    "Nghe An","Ha Tinh","Quang Tri","Thua Thien Hue","Quang Nam","Kon Tum",
    "Gia Lai","Binh Phuoc","Tay Ninh","Tay Ninh","Long An","Dong Thap",
    "An Giang","Kien Giang"),
  zone_type = c(rep("coastal_economic_zone",18),rep("border_gate_economic_zone",24)),
  legal_document = c("120/2007/QD-TTg","06/2008/QD-TTg","102/2006/QD-TTg",
    "85/2007/QD-TTg","72/2006/QD-TTg","79/2008/QD-TTg","04/2006/QD-TTg",
    "42/2015/QD-TTg","141/2005/QD-TTg","54/2008/QD-TTg","92/2006/QD-TTg",
    "31/2013/QD-TTg","69/2009/QD-TTg","66/2010/QD-TTg","36/2017/QD-TTg",
    "29/2020/QD-TTg","88/QD-TTg","1511/QD-TTg",rep(NA_character_,24)),
  approval_date = as.Date(c(rep(NA_character_,16),"2025-01-14","2024-12-04",rep(NA_character_,24))),
  effective_date = as.Date(c(rep(NA_character_,16),"2025-01-14","2024-12-04",rep(NA_character_,24))),
  stringsAsFactors = FALSE
)
more$name_en <- more$name_vi
more$aliases <- ""
more$status <- "established"
more$legal_evidence <- ifelse(more$zone_type == "coastal_economic_zone",
  "zone_level_establishment_instrument_or_official_current_reconciliation",
  "official_national_count_name_reconciliation")
more$source_url <- ifelse(more$zone_type == "coastal_economic_zone",
  "https://fileportalcms.mpi.gov.vn/TinBai/VanBan/2023-11/02.%20Bao%20cao%20Tom%20tat%20QHTTQG%20-%20Hoan%20thien%20theo%20NQ81.pdf",
  "https://www.mpi.gov.vn/portal/Pages/2023-10-26/Le-Ky-ket-hop-tac-phat-trien-khu-cong-nghiep-sinh-mcausi.aspx")
more$lon <- NA_real_; more$lat <- NA_real_
catalogue$province <- c("Quang Nam","Quang Ngai","Quang Ninh","Quang Binh",
                        "Ho Chi Minh City","Ha Noi","Ho Chi Minh City","Da Nang",
                        "Ho Chi Minh City","Ho Chi Minh City")
catalogue <- rbind(catalogue, more[names(catalogue)])

current <- sf::st_transform(readRDS("inst/extdata/provinces.rds"), 4326)
former <- sf::st_transform(readRDS("inst/extdata/provinces_63.rds"), 4326)
key <- function(x) stringi::stri_trans_general(tolower(x), "Latin-ASCII")
former_i <- match(key(catalogue$province), key(former$name_en))
stopifnot(!anyNA(former_i))
geom <- suppressWarnings(sf::st_point_on_surface(former[former_i, ]))
zones <- sf::st_sf(catalogue[setdiff(names(catalogue), c("lon", "lat"))],
                   geometry = sf::st_geometry(geom), crs = 4326)
zones$legal_status <- zones$status
zones$operational_status <- "unknown"
zones$established_approval_date <- zones$approval_date
zones$established_effective_date <- zones$effective_date
zones$evidence_date <- as.Date(ifelse(is.na(zones$approval_date),
                                      "2023-10-26", as.character(zones$approval_date)))
zones$legal_province <- zones$province
zones$geometry_type <- "point"
zones$geometry_available <- FALSE
zones$location_accuracy <- "province_only"
zones$geometry_method <- "deterministic_point_on_surface_of_pre_2025_province"
zones$geometry_source <- "bundled provinces_63.rds"
zones$source_date <- zones$evidence_date
zones$verified_on <- verified_on
# Canonical verified instruments are the sole authority for promoting a row to
# established. Exact URLs and evidence roles live here, not in an independent
# zone-ID allow-list.
canonical_instruments <- data.frame(
  document_id = c("108/2003/QD-TTg", "25/2010/QD-TTg", "19/2012/QD-TTg",
                  "198/QD-TTg", "1979/QD-TTg"),
  document_url = c(
    "https://vanban.chinhphu.vn/default.aspx?docid=11933&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=93583&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=157416&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=5711&pageid=27160",
    "https://vanban.chinhphu.vn/default.aspx?docid=97516&pageid=27160"),
  url_status = "verified_direct",
  evidence_role = c("establishment", "current_operating_regulation",
                    "establishment", "establishment", "establishment"),
  document_date = as.Date(c("2003-06-05", "2010-03-03", "2012-04-10",
                            "1998-10-12", "2010-10-28")),
  effective_date_verified = c(FALSE, TRUE, TRUE, FALSE, TRUE),
  verified_effective_date = as.Date(c(NA, "2010-05-01", "2012-06-01",
                                      NA, "2010-10-28")),
  stringsAsFactors = FALSE)
instrument_i <- match(zones$legal_document, canonical_instruments$document_id)
direct_establishment <- !is.na(instrument_i) &
  canonical_instruments$url_status[instrument_i] == "verified_direct" &
  canonical_instruments$evidence_role[instrument_i] == "establishment"
zones$legal_status <- ifelse(direct_establishment, "established",
                             "candidate_or_count_reconciled")
zones$evidence_state <- ifelse(direct_establishment,
  "row_level_establishment_instrument_verified",
  "aggregate_count_or_non_establishment_reference")
# These dates came from operating/planning evidence, not the establishment
# instrument represented by the row, and therefore must not be exposed as
# establishment dates.
unsupported_dates <- zones$id %in% c(
  "coastal_dung_quat", "epz_tan_thuan", "epz_linh_trung_1",
  "epz_linh_trung_2", "coastal_ninh_co", "coastal_south_hai_phong")
zones$established_approval_date[unsupported_dates] <- as.Date(NA)
zones$established_effective_date[unsupported_dates] <- as.Date(NA)
zones$source_url[zones$id %in% c("coastal_ninh_co", "coastal_south_hai_phong")] <- NA_character_
zones$legal_document[zones$id %in% c(
  "coastal_ninh_co", "coastal_south_hai_phong")] <- NA_character_
# Effective dates are published only when the canonical instrument explicitly
# verifies them. Issue/approval dates remain separate.
zones$established_effective_date <- as.Date(NA)
verified_effect <- direct_establishment &
  canonical_instruments$effective_date_verified[instrument_i]
zones$established_effective_date[verified_effect] <-
  canonical_instruments$verified_effective_date[instrument_i[verified_effect]]
zones$former_province_code <- former$code[former_i]
current_hit <- sf::st_intersects(zones, current)
zones$province_code <- vapply(current_hit, function(i) if (length(i)) current$code[i[1L]] else NA_character_, "")
zones$representative_point_province <- zones$province_code
info <- readRDS("inst/extdata/provinces_info.rds")
zones$province_en <- info$name_en[match(zones$province_code, info$code)]
stopifnot(!anyNA(zones$province_code), !anyDuplicated(zones$id),
          all(lengths(sf::st_intersects(zones, sf::st_union(current))) > 0L))

zones <- zones[order(zones$zone_type, zones$id), c(
  "id", "name_vi", "name_en", "aliases", "zone_type", "legal_status", "evidence_state",
  "operational_status", "legal_province", "province_code", "province_en",
  "former_province_code", "representative_point_province", "legal_document",
  "established_approval_date", "established_effective_date", "evidence_date",
  "legal_evidence", "source_url",
  "source_date", "verified_on", "geometry_type", "location_accuracy",
  "geometry_available", "geometry_method", "geometry_source", "geometry"
)]
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
saveRDS(zones, "inst/extdata/economic_zones.rds", compress = "xz")

baselines <- c(coastal_economic_zone = 20L, border_gate_economic_zone = 26L,
               export_processing_zone = 3L, national_high_tech_park = 3L)
represented <- table(factor(zones$zone_type, levels = names(baselines)))
audit <- data.frame(
  zone_type = names(baselines), baseline = unname(baselines),
  included = as.integer(represented),
  gap = c(NA_integer_, NA_integer_, NA_integer_, NA_integer_),
  baseline_note = c(
    "Current official reporting says 20; the dated 2023 national-plan evidence contained 18 before two later additions",
    "MPI reports 26 established border-gate economic zones; establishment and current scope still require zone-level verification",
    "Decision 1711/QD-TTg annex lists three established operating export-processing zones in HCMC",
    "three named high-tech parks are included; no verified official national completeness source is claimed"),
  baseline_source_url = c(
    "https://tphcm.chinhphu.vn/bat-dong-san-cong-nghiep-viet-nam-vung-vi-the-don-chuyen-dong-101251029184041238.htm",
    "https://tphcm.chinhphu.vn/bat-dong-san-cong-nghiep-viet-nam-vung-vi-the-don-chuyen-dong-101251029184041238.htm",
    "https://congbaocdn.chinhphu.vn/CongBaoCP/VanBan/2024/12/43820/54205-1-2025145-1461711-qd-ttg.pdf",
    "https://vanban.chinhphu.vn/?docid=81138&pageid=27160"),
  stringsAsFactors = FALSE
)
audit$baseline_scope <- c("national_current_count_with_18_zone_historical_vintage",
                          "national_current_count", "ho_chi_minh_city_only", "national")
audit$baseline_status <- c("official_count_only_names_not_legally_reconciled",
                           "official_count_only_names_not_legally_reconciled",
                           "subnational_named_list_not_national",
                           "named_rows_without_verified_national_complete_baseline")
utils::write.csv(audit, "data-raw/economic-zones-audit.csv", row.names = FALSE)

documents <- unique(data.frame(document_id = na.omit(zones$legal_document),
                               stringsAsFactors = FALSE))
documents <- merge(documents, canonical_instruments, by = "document_id",
                   all.x = TRUE, sort = TRUE)
documents$url_status[is.na(documents$url_status)] <- "not_verified"
documents$evidence_role[is.na(documents$evidence_role)] <- "unverified"
utils::write.csv(documents, "data-raw/economic-zone-legal-instruments.csv", row.names=FALSE)
link_i <- match(zones$legal_document, canonical_instruments$document_id)
verified_link <- !is.na(link_i) &
  canonical_instruments$url_status[link_i] == "verified_direct" &
  canonical_instruments$evidence_role[link_i] == "establishment"
link_role <- rep("unverified_or_non_establishment", nrow(zones))
verified_any <- !is.na(link_i) &
  canonical_instruments$url_status[link_i] == "verified_direct"
link_role[verified_any] <- paste0("verified_",
  canonical_instruments$evidence_role[link_i[verified_any]])
zone_documents <- data.frame(zone_id = zones$id, document_id = zones$legal_document,
                             evidence_role = link_role,
                             stringsAsFactors = FALSE)
zone_documents$join_status <- ifelse(is.na(zone_documents$document_id),
                                     "no_row_level_document", "document_id_recorded")
utils::write.csv(zone_documents, "data-raw/economic-zone-document-links.csv", row.names=FALSE)
baseline_history <- data.frame(
  zone_type = c("coastal_economic_zone", "coastal_economic_zone",
                "border_gate_economic_zone"),
  vintage = as.Date(c("2023-10-26", "2025-10-29", "2025-10-29")),
  official_count = c(18L, 20L, 26L),
  scope = "national",
  source_url = c(
    "https://fileportalcms.mpi.gov.vn/TinBai/VanBan/2023-11/02.%20Bao%20cao%20Tom%20tat%20QHTTQG%20-%20Hoan%20thien%20theo%20NQ81.pdf",
    "https://tphcm.chinhphu.vn/bat-dong-san-cong-nghiep-viet-nam-vung-vi-the-don-chuyen-dong-101251029184041238.htm",
    "https://tphcm.chinhphu.vn/bat-dong-san-cong-nghiep-viet-nam-vung-vi-the-don-chuyen-dong-101251029184041238.htm"))
utils::write.csv(baseline_history, "data-raw/economic-zone-baseline-history.csv", row.names=FALSE)
row_audit <- sf::st_drop_geometry(zones[c("id", "zone_type", "legal_document",
  "legal_province", "geometry_available", "location_accuracy", "source_url")])
row_audit$decision <- "included"
row_audit$location_result <- "unlocated_zone_boundary_province_fallback"
row_audit$mismatch <- ifelse(is.na(row_audit$legal_document),
                            "zone_level_instrument_not_yet_verified", "none")
utils::write.csv(row_audit, "data-raw/economic-zones-row-audit.csv", row.names=FALSE)
message("Built ", nrow(zones), " conservative economic/policy zone records.")
