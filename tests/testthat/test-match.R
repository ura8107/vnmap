test_that("administrative prefixes are removed only when the tone agrees", {
  key <- vnmap:::.vn_key
  # "Tinh" with a hook above is the word for province and is removed.
  expect_equal(key("Tỉnh Cao Bằng"), "caobang")
  expect_equal(key("Thành phố Hồ Chí Minh"), "hochiminh")
  expect_equal(key("Xã Tân Phú"), "tanphu")

  # The same syllables with a different tone open a real unit name and stay.
  # Before this rule these normalized to "bien", "khe", "gia", "tuc" and "ng".
  expect_equal(key("Tịnh Biên"), "tinhbien")
  expect_equal(key("Tịnh Khê"), "tinhkhe")
  expect_equal(key("Tĩnh Gia"), "tinhgia")
  expect_equal(key("Tĩnh Túc"), "tinhtuc")
  expect_equal(key("Thạnh Phong"), "thanhphong")
  expect_equal(key("Thanh Phong"), "thanhphong")
})

test_that("the tone-preserving key keeps units that ASCII folds together", {
  norm <- vnmap:::.vn_norm
  expect_false(norm("Mỹ Tho") == norm("Mỹ Thọ"))
  expect_false(norm("Tân Thành") == norm("Tân Thạnh"))
  expect_equal(vnmap:::.vn_key("Mỹ Tho"), vnmap:::.vn_key("Mỹ Thọ"))
})

test_that("an undiacriticked prefix is handled by the last stage only", {
  expect_equal(vnmap:::.vn_key_loose("Tinh Cao Bang"), "caobang")
  # The loose key is destructive, which is why it is consulted last.
  expect_equal(vnmap:::.vn_key_loose("Tịnh Biên"), "bien")
})

test_that("word order is not treated as a naming variant", {
  # Borrowed matching rules do not all transfer: sorting words apart resolves
  # "24 Parganas North" against "North 24 Parganas" in India, but Vietnamese
  # place names have a fixed order, so it would only invent matches.
  expect_true(is.na(vn_match("Noi Ha")$code))
})

test_that("no two communes in one province share a tone-preserving key", {
  lk <- vnmap:::.vn_lookup("communes")
  k <- paste(lk$tab$parent_code, vnmap:::.vn_norm(lk$tab$name_vi))
  expect_equal(anyDuplicated(k), 0L)
})

test_that("recorded name cases resolve to the expected unit and stage", {
  cases <- utils::read.csv(test_path("fixtures", "name-cases.csv"),
                           colClasses = "character", na.strings = character(0),
                           encoding = "UTF-8")
  for (i in seq_len(nrow(cases))) {
    parent <- if (nzchar(cases$parent[i])) cases$parent[i] else NULL
    got <- vn_match(cases$input[i], geography = cases$geography[i], parent = parent)
    expect_equal(got$match_type, cases$expect_type[i], info = cases$input[i])
    want <- if (cases$expect_code[i] == "NA") NA_character_ else cases$expect_code[i]
    expect_equal(got$code, want, info = cases$input[i])
  }
})

test_that("suggestions are reported but never applied", {
  got <- vn_match("Hanoii")
  expect_equal(got$match_type, "fuzzy")
  expect_true(is.na(got$code))
  expect_equal(got$n_candidates, 1L)
  expect_match(got$candidate_names, "Hà Nội")
  expect_equal(got$distance, 1L)

  # A caller can switch suggestions off entirely.
  expect_equal(vn_match("Hanoii", max_distance = 0)$match_type, "none")
})

test_that("ambiguity is reported instead of resolved", {
  got <- vn_match("Tan Phu", geography = "communes")
  expect_equal(got$match_type, "ambiguous")
  expect_true(is.na(got$code))
  expect_equal(got$n_candidates, 6L)
  expect_equal(length(strsplit(got$candidates, "|", fixed = TRUE)[[1]]), 6L)
})

test_that("a trailing parent is only split off when it names a province", {
  split <- vnmap:::.vn_split_parent(c("Tan Phu, Dong Nai", "Xuan Loc, khu 3"), "provinces")
  expect_equal(split$name, c("Tan Phu", "Xuan Loc, khu 3"))
  expect_equal(split$hint, c("Dong Nai", NA_character_))
})

test_that("a name absent from the requested parent reports where it does occur", {
  got <- vn_match("Tan Phu", geography = "communes", parent = "Ha Noi")
  expect_equal(got$match_type, "none")
  expect_true(is.na(got$code))
  expect_equal(got$n_candidates, 6L)
})

test_that("vn_match validates its arguments", {
  expect_error(vn_match("Ha Noi", parent = "Ha Noi"), "lower-level geography")
  expect_error(vn_match("Ha Noi", max_distance = -1), "non-negative")
  expect_error(vn_match("Ha Noi", geography = "districts"), "should be one of")
  expect_equal(nrow(vn_match(character(0))), 0L)
})

test_that("vn_match returns one row per input, in order", {
  x <- c("Ha Noi", "Atlantis", "48", NA_character_)
  got <- vn_match(x)
  expect_equal(nrow(got), 4L)
  expect_equal(got$input, x)
  expect_equal(got$code, c("01", NA, "48", NA))
})

test_that("province_code resolves exactly what it always did", {
  expect_equal(province_code(c("Đà Nẵng", "Da Nang", "Danang")), rep("48", 3))
  expect_equal(province_code(c("HCMC", "Sài Gòn")), rep("79", 2))
  expect_equal(province_code("Tinh Cao Bang"), "04")
  expect_equal(province_code("Bac Giang", geography = "provinces_63"), "24")
  expect_error(province_code("Atlantis"), "Unknown")
})

test_that("an unmatched name is offered the closest unit", {
  expect_error(province_code("Hanoii"), 'did you mean "Hà Nội" \\(01\\)')
  expect_error(province_code("Atlantis"), "Unknown province or municipality")
  # A name with no near neighbour is reported without inventing one.
  expect_false(grepl("did you mean", tryCatch(province_code("Atlantis"),
                                              error = conditionMessage)))
})

test_that("a table prepared for the other geography says so", {
  msg <- tryCatch(province_code(c("Bac Giang", "Vinh Phuc", "Binh Duong")),
                  error = conditionMessage)
  expect_match(msg, "match the pre-July-2025 geography")
  expect_match(msg, 'geography = "provinces_63"')

  # The check is symmetric but fires in practice only in this direction: the
  # 2025 reform kept the surviving unit names, so 29 of the 63 former names are
  # gone from the current geography while only one current name ("Hue") is
  # absent from the former one -- below the two-name threshold.
  expect_equal(
    sum(is.na(vn_match(province_info()$name_en, "provinces_63", max_distance = 0)$code)),
    1L
  )

  # One stray name is a typo, not a geography mix-up.
  one <- tryCatch(province_code(c("Ha Noi", "Hai Phong", "Bac Giang")),
                  error = conditionMessage)
  expect_false(grepl("Did you mean geography", one))
})

test_that("commune_code resolves and refuses to guess", {
  expect_equal(commune_code("Tan Phu, Dong Nai"), "26116")
  expect_equal(commune_code("Tan Phu", province = "Dong Nai"), "26116")
  expect_equal(commune_code("Tinh Bien"), "30520")
  expect_error(commune_code("Tan Phu"), "matches several units")
  expect_error(commune_code("Tan Phu"), "Supply `province`")
})

test_that("the two Thanh Phong communes are distinguishable again", {
  # Both normalized to "ng" before the prefix fix, so they collided with each
  # other and with anything else the rule truncated to two letters.
  expect_equal(commune_code("Thạnh Phong"), "29227")
  expect_equal(commune_code("Thanh Phong", province = "Thanh Hoa"), "16213")
  # Written without tone marks they are genuinely two units, and saying so is
  # the correct answer rather than returning both.
  expect_error(commune_code("Thanh Phong"), "matches several units")
})

test_that("an ambiguity a province cannot settle says so instead", {
  msg <- tryCatch(commune_code("My Tho", province = "Dong Thap"),
                  error = conditionMessage)
  expect_match(msg, "differ only by")
  expect_false(grepl("Supply `province`", msg))
  expect_equal(commune_code(c("Mỹ Tho", "Mỹ Thọ")), c("28261", "30076"))
})

test_that("include is narrowed by province before it is matched", {
  skip_if_not_installed("sf")
  # Six communes are called Tan Phu, but only one of them is in Dong Nai.
  expect_equal(nrow(vn_map("communes", province = "Dong Nai", include = "Tan Phu")), 1L)
  expect_error(vn_map("communes", include = "Tan Phu"), "matches several units")
  expect_equal(nrow(vn_map("communes", include = "Tan Phu, Dong Nai")), 1L)
  expect_error(vn_map("communes", include = "Atlantis"), "Unknown commune")
})
