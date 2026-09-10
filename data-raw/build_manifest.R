# Fill in the mechanical fields of inst/extdata/manifest.json.
#
# The descriptive fields -- source, licence, vintage, accuracy, basis -- are
# written by hand and are authoritative. This script only recomputes the two
# that describe the artifacts themselves, so that a rebuilt layer whose
# manifest was not updated fails the test suite instead of quietly describing
# the previous build.
#
# Run from the package root:
#     Rscript data-raw/build_manifest.R
# or  make manifest

root <- normalizePath(".")
path <- file.path(root, "inst", "extdata", "manifest.json")
manifest <- jsonlite::read_json(path)

# Rows in a layer: a data frame or sf layer counts its own rows; regions.rds
# holds one frame per geography and counts both.
n_features <- function(x) {
  if (is.data.frame(x)) return(nrow(x))
  if (is.list(x)) return(sum(vapply(x, nrow, integer(1))))
  length(x)
}

# `storage` says where a dataset ends up. Files under inst/extdata/ ship as
# they are, so their checksums can be verified after installation. Datasets
# under data/ are folded into the lazy-load database by `LazyData: true` and no
# longer exist as separate files, so their checksum describes the repository
# file only; the tests verify their row counts instead.
read_layer <- function(file) {
  if (grepl("\\.rda$", file)) {
    env <- new.env(parent = emptyenv())
    load(file, envir = env)
    return(get(ls(env)[1L], envir = env))
  }
  readRDS(file)
}

manifest$package_version <- as.character(
  read.dcf(file.path(root, "DESCRIPTION"), "Version")[1L, 1L]
)

for (i in seq_along(manifest$layers)) {
  entry <- manifest$layers[[i]]
  file <- file.path(root, sub("^extdata/", "inst/extdata/", entry$file))
  if (!file.exists(file)) stop("Missing layer file: ", entry$file, call. = FALSE)
  manifest$layers[[i]]$md5 <- unname(tools::md5sum(file))
  manifest$layers[[i]]$n_features <- n_features(read_layer(file))
  message(sprintf("%-24s %6d features  %s", entry$layer,
                  manifest$layers[[i]]$n_features, manifest$layers[[i]]$md5))
}

jsonlite::write_json(manifest, path, pretty = TRUE, auto_unbox = TRUE,
                     null = "null")
message("Wrote ", path)
