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

test_that("word order and undiacriticked prefixes are handled by later stages", {
  expect_equal(vnmap:::.vn_tokens("Ha Noi"), vnmap:::.vn_tokens("Noi Ha"))
  expect_equal(vnmap:::.vn_key_loose("Tinh Cao Bang"), "caobang")
  # The loose key is destructive, which is why it is consulted last.
  expect_equal(vnmap:::.vn_key_loose("Tịnh Biên"), "bien")
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
  split <- vnmap:::.vn_split_parent(c("Tan Phu, Dong Nai", "Xuan Loc, khu 3"), "communes")
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
