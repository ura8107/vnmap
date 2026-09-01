# Contributing to vnmap

Issues and pull requests are welcome at
<https://github.com/ura8107/vnmap/issues>.

For code changes:

1.  Fork and clone the repository.
2.  Install the package dependencies.
3.  Run `Rscript data-raw/build_data.R` only when boundary data or
    metadata changes.
4.  Run `R CMD build .` and `R CMD check --no-manual vnmap_*.tar.gz`.
5.  Include tests for behavior changes.

Please do not commit generated check directories or source tarballs.
