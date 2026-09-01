# Download the NSO old/new administrative-unit workbook

Download the NSO old/new administrative-unit workbook

## Usage

``` r
download_administrative_crosswalk(
  destfile = file.path(getwd(), "nso-admin-crosswalk-new-old.xlsx"),
  overwrite = FALSE
)
```

## Arguments

- destfile:

  Destination for the downloaded `.xlsx` file.

- overwrite:

  Whether to replace an existing file.

## Value

The normalized destination path, invisibly.

## Details

Download is explicit because `vnmap` has not established terms
permitting redistribution of the NSO workbook or a substantial extracted
table. The file remains under its source's terms and is not bundled.
