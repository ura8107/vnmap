manifest_path <- function() {
  path <- system.file("extdata", "manifest.json", package = "vnmap")
  skip_if(!nzchar(path), "manifest.json is not installed")
  path
}

installed_file <- function(entry) {
  system.file(entry$file, package = "vnmap")
}

# Datasets under data/ are folded into the lazy-load database by `LazyData`, so
# they cannot be read back as files. Load them by name instead.
load_layer <- function(entry) {
  if (entry$storage == "lazydata") {
    env <- new.env(parent = emptyenv())
    utils::data(list = entry$layer, package = "vnmap", envir = env)
    return(get(entry$layer, envir = env))
  }
  readRDS(installed_file(entry))
}

test_that("the manifest is well formed", {
  skip_if_not_installed("jsonlite")
  m <- jsonlite::read_json(manifest_path())
  expect_equal(m$schema_version, 1L)
  expect_true(length(m$layers) > 0L)

  required <- c("layer", "file", "storage", "title", "description", "md5",
                "n_features", "crs", "geometry_vintage", "geometry_accuracy",
                "administrative_basis", "source", "build_script")
  for (entry in m$layers) {
    for (field in required) {
      expect_true(field %in% names(entry),
                  info = paste(entry$layer, "is missing", field))
    }
    expect_true(entry$storage %in% c("extdata", "lazydata"), info = entry$layer)
    for (field in c("name", "url", "license")) {
      expect_true(field %in% names(entry$source),
                  info = paste(entry$layer, "source is missing", field))
      expect_true(nzchar(as.character(entry$source[[field]])),
                  info = paste(entry$layer, "source", field, "is empty"))
    }
  }
})

test_that("the manifest describes the files that shipped", {
  skip_if_not_installed("jsonlite")
  m <- jsonlite::read_json(manifest_path())
  # Only files that ship as files can be checksummed after installation; a
  # lazy-loaded dataset is verified by its row count below instead.
  for (entry in Filter(function(e) e$storage == "extdata", m$layers)) {
    file <- installed_file(entry)
    expect_true(nzchar(file), info = paste(entry$layer, "file is missing"))
    expect_equal(unname(tools::md5sum(file)), entry$md5,
                 info = paste(entry$layer, "checksum is stale; run `make manifest`"))
  }
})

test_that("recorded feature counts match the layers as built", {
  skip_if_not_installed("jsonlite")
  m <- jsonlite::read_json(manifest_path())
  count <- function(x) {
    if (is.data.frame(x)) return(nrow(x))
    if (is.list(x)) return(sum(vapply(x, nrow, integer(1))))
    length(x)
  }
  for (entry in m$layers) {
    obj <- load_layer(entry)
    expect_equal(count(obj), entry$n_features,
                 info = paste(entry$layer, "count is stale; run `make manifest`"))
  }
})

test_that("every shipped dataset is described", {
  skip_if_not_installed("jsonlite")
  m <- jsonlite::read_json(manifest_path())
  described <- vapply(m$layers, function(e) basename(e$file), character(1))

  dir <- system.file("extdata", package = "vnmap")
  # districts_63 and communes_63 are built on demand and never shipped.
  shipped <- setdiff(list.files(dir, pattern = "\\.rds$"),
                     c("districts_63.rds", "communes_63.rds"))
  expect_setequal(shipped, grep("\\.rds$", described, value = TRUE))

  exported <- utils::data(package = "vnmap")$results[, "Item"]
  expect_setequal(exported, sub("\\.rda$", "", grep("\\.rda$", described, value = TRUE)))
})

test_that("the manifest tracks the package version", {
  skip_if_not_installed("jsonlite")
  m <- jsonlite::read_json(manifest_path())
  expect_equal(m$package_version, as.character(utils::packageVersion("vnmap")))
})

test_that("vn_provenance returns the manifest as a data frame", {
  got <- vn_provenance()
  expect_s3_class(got, "data.frame")
  expect_true(all(c("layer", "source_license", "geometry_vintage", "md5") %in% names(got)))
  expect_equal(anyDuplicated(got$layer), 0L)

  one <- vn_provenance("communes")
  expect_equal(nrow(one), 1L)
  expect_equal(one$source_license, "MIT")
  expect_equal(one$geometry_accuracy, "generalized to 100 m")

  # Order follows the request, as elsewhere in the package.
  pair <- vn_provenance(c("regions", "provinces"))
  expect_equal(pair$layer, c("regions", "provinces"))

  expect_error(vn_provenance("districts_63"), "Unknown layer")
})

test_that("provenance agrees with what the layers actually claim", {
  skip_if_not_installed("sf")
  # The commune layer carries its own vintage column; the manifest must not
  # drift from it.
  communes <- vn_map("communes", province = "Ha Noi", crs = 4326)
  expect_equal(unique(as.character(communes$geography_vintage)),
               vn_provenance("communes")$geometry_vintage)
  expect_equal(sf::st_crs(readRDS(system.file("extdata", "provinces_63.rds",
                                              package = "vnmap")))$input,
               vn_provenance("provinces_63")$crs)
})
