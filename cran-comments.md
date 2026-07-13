## R CMD check results

Checked with `R CMD check --as-cran` on:

* macOS (aarch64), R 4.5.3

There were 0 errors, 0 warnings, and 1 note:

* `checking for future file timestamps ... NOTE unable to verify current time`

This is caused by the isolated local check environment being unable to contact
an external time service. It is not caused by files with future timestamps.

## Reverse dependencies

This is a new submission, so there are no reverse dependencies.

## Data and administrative boundaries

The package contains generalized public-domain boundary data from
geoBoundaries (boundary ID VNM-ADM1-63759600). The source represents an older
administrative geography. The included current 34-unit layer is produced by
dissolving those boundaries according to Viet Nam Decision 19/2025/QD-TTg,
effective 1 July 2025. The package documentation clearly states that the data
are intended for statistical visualization, not surveying or navigation.

