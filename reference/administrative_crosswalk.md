# Parse and query the 2025 administrative-unit crosswalk

Parse and query the 2025 administrative-unit crosswalk

## Usage

``` r
administrative_crosswalk(path, current = NULL, former = NULL, province = NULL)
```

## Arguments

- path:

  Path to the official NSO `.xlsx` workbook, normally obtained with
  [`download_administrative_crosswalk()`](https://ura8107.github.io/vnmap/reference/download_administrative_crosswalk.md).

- current:

  Optional current commune names or five-digit codes.

- former:

  Optional former commune names or five-digit codes.

- province:

  Optional current or former provincial identifier accepted by
  [`province_code()`](https://ura8107.github.io/vnmap/reference/province_code.md).
  Rows matching either geography are retained.

## Value

A data frame. The `relation` column is `"whole"` or `"part"`.
Reconciliation with the bundled 2026 snapshot is reported in
`current_code_status` and in the `crosswalk_only_codes` and
`current_snapshot_only_codes` attributes.

## Details

This table is inherently many-to-many: a former unit may be split among
current units, and a current unit may combine several former units. It
is a membership crosswalk, not an allocation-weight table. The source
publishes no population or area shares, so none are inferred.

The workbook describes the July 2025 transition while bundled current
boundaries are a 25 July 2026 observed snapshot. Status fields expose
differences rather than silently coercing codes between vintages. No
per-code legal effective date is assigned.

## Examples

``` r
if (FALSE) { # \dontrun{
path <- download_administrative_crosswalk(tempfile(fileext = ".xlsx"))
administrative_crosswalk(path, current = "00004")
} # }
```
