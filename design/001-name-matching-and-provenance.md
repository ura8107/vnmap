# Design note 001: name matching and machine-readable provenance

Status: accepted; workstreams A and B implemented
Date: 2026-09-10
Scope: `R/codes.R`, `R/vn-map.R`, `inst/extdata/manifest.json`, `tests/testthat/`

This note records what was taken from a survey of an unrelated project,
the design that follows from it, and the decisions that were settled
before implementation started. It is build documentation, not user
documentation; nothing here is part of the package's public contract
until the corresponding function is exported and documented in `man/`.

---

## 1. What was surveyed

`yashveeeeeeer/india-geodata` (CC BY 4.0) is a data repository plus a
static web application, not an R package. It aggregates roughly 1,800
files across 14 source collections, keeping small files in the
repository and moving large ones to GitHub Releases.

Three parts of it are relevant here:

| Component | What it does |
|---|---|
| `docs/assets/js/maps-core.js` (187 lines), `maps.js` (1,959 lines) | Browser choropleth builder: paste a table, get a coloured map, export PNG/SVG/PDF |
| `scripts/build-map-layers.py` | Release parquet to geopandas to mapshaper to simplified TopoJSON |
| `data/**/metadata.json` plus `scripts/validate-metadata.py` and CI | Machine-readable source, licence and storage records, validated on every pull request |

The two projects have different shapes. `india-geodata` is a
distribution problem solved with a catalogue; `vnmap` is an API problem
solved with a bundled, provenance-tracked dataset. Most of the
catalogue machinery does not transfer. Two things do.

## 2. What transfers

### 2.1 Staged name matching with candidate reporting

`matchName()` in `maps.js` descends through a cascade rather than
attempting one comparison:

```
numeric input to code lookup
  -> "Name, Parent" / "Name (Parent)" split, guarded by a real parent-name check
  -> user-taught alias
  -> static alias table
  -> word-order-insensitive key
  -> prefix match, restricted to comparable lengths
  -> Levenshtein within a length-dependent tolerance
  -> parent hint to narrow multiple candidates
  -> otherwise report as ambiguous with candidates
```

Two properties matter more than the cascade itself. It records *which*
step produced the match (`lastMatchKind`), and it reports names that
failed with up to three ranked candidates instead of discarding them.

`vnmap` normalises with a single function and raises an error on the
first failure. At the 34-unit and 63-unit provincial levels this is
adequate. At the commune level, which the package now bundles, it is
not: commune names repeat heavily across provinces, so a lookup without
a parent hint is genuinely ambiguous rather than merely unmatched.

### 2.2 Machine-readable provenance validated in CI

`india-geodata` requires every dataset to carry `metadata.json` with
`name`, `title`, `description`, `category`, `coverage`, `sources`,
`license`, `formats`, `coordinate_system` and `storage`, and validates
the structure on every pull request touching those files.

`vnmap` already records more than this, but as prose in
`data-raw/README.md`, as Debian-style stanzas in `inst/COPYRIGHTS`, as
checksum CSVs under `data-raw/source/`, and as `@details` sections in
the Rd documentation. None of it is machine-readable and none of it is
checked against the artifacts it describes.

## 3. What does not transfer

`scripts/download-releases.py`, `scripts/generate-catalog.py` and the
Jekyll catalogue site solve a data-portal problem. `vnmap` is a single
package with nine bundled layers and a pkgdown site; this machinery
would be overhead with no corresponding benefit.

## 4. Defect found during the survey

`.vn_key()` in `R/codes.R` removes punctuation *before* stripping
administrative prefixes:

```r
x <- tolower(gsub("[^a-zA-Z0-9]", "", x))
sub("^(tinh|thanhpho)", "", x)
```

Word boundaries are gone by the time the prefix is stripped, so any
unit whose name *begins* with those syllables is truncated:

| Input | Current key | Correct key |
|---|---|---|
| Tinh Bien (An Giang) | `bien` | `tinhbien` |
| Thanh Phong (Ben Tre) | `ng` | `thanhphong` |
| Tinh Khe (Quang Ngai) | `khe` | `tinhkhe` |

Measured against the bundled layer, six communes are affected: the four
above plus `Tinh Tuc` in Cao Bang, and `Thanh Phong` in Thanh Hoa
together with `Thanh Phong` in Vinh Long, which both reduce to `ng` and
so collide with each other. No provincial-level unit is affected, which
is why this never surfaced before the commune layer was bundled and
matched through the same function by `.match_units()`.

Tokenising before stripping is not sufficient: the first syllable really
is a separate word. What separates the two uses is the tone. The word
for province carries a hook above; these names carry a dot below or a
tilde. The same holds for the word for city against `Thanh Phong`. So
prefix removal must compare tone-marked forms. Checked across all 10,807
bundled names and aliases, exactly one is affected by that rule --- the
alias `"Thanh pho Ho Chi Minh"` --- which is the intended case.

Prefix stripping must run on token boundaries, before punctuation is
removed. Fixing it changes normalisation output for affected inputs and
is therefore a behaviour change, recorded in `NEWS.md` as a fix.

## 5. Design A: name matching

Guiding constraint: **the existing return values and the exact
success/failure boundary of `province_code()` do not change.** Edit
distance is used only to populate error messages. Everything added is
diagnostic.

### 5.1 Three-stage normalisation

```r
.vn_norm(x)       # NFC, tone-exact prefix removal, lowercase, punctuation removed.
                  # Tone marks preserved.  "Tinh Bien" -> "tinhbien"
.vn_key(x)        # .vn_norm() folded to ASCII. Existing name and role, defect fixed.
.vn_key_loose(x)  # ASCII, leading prefix removed tone-blind. Destructive; last resort.
```

A caller who writes `"Tinh Cao Bang"` without diacritics gives the
matcher nothing to compare the tone against. Stripped of tones that
prefix is indistinguishable from the first syllable of `Tinh Bien`, so
the loose key cannot be used as a general normaliser. It is consulted
only after the tone-preserving and ASCII keys have both failed, by which
point `Tinh Bien` has already resolved and never reaches it.

Prefixes removed as whole tokens: `tinh`, `thanh pho`, `tp`, `xa`,
`phuong`, `thi tran`, `thi xa`, `quan`, `huyen`.

Introducing a tone-preserving stage is the substantive change. The
current function applies Latin-ASCII first, collapsing `Hoa`, `Hoa`
and `Hoa` (differing only in diacritics) onto one key. Harmless across
34 or 63 provinces; a real collision across 3,321 communes. Trying
`.vn_norm()` first and falling back to `.vn_key()` lets the two cases
be distinguished and reported separately.

### 5.2 `vn_match()`

```r
vn_match(x,
         geography    = c("provinces", "provinces_63", "communes"),
         parent       = NULL,
         max_distance = 1)
```

Returns a data frame with one row per element of `x`:

| Column | Meaning |
|---|---|
| `input` | the string supplied |
| `code` | resolved code, `NA` when unresolved |
| `name_vi`, `name_en`, `parent_code` | populated on resolution only |
| `match_type` | `code`, `exact`, `ascii`, `loose`, `fuzzy`, `ambiguous`, `none` |
| `matched_on` | the name or alias that produced the match |
| `distance` | edit distance, for `fuzzy` only |
| `n_candidates` | number of candidates considered |
| `candidates` | `\|`-separated codes |
| `candidate_names` | `\|`-separated display names, parent-qualified |

Candidate columns are `|`-separated character, not list columns: the
result stays a plain data frame that prints correctly without tibble
and writes to CSV unchanged.

Cascade, stopping at the first step that resolves:

```
1. direct code or ISO match              -> "code"
2. .vn_norm() exact match (tones kept)   -> "exact"
3. .vn_key() match (tones dropped)       -> "ascii"
4. .vn_key_loose() match (prefix)        -> "loose"
5. Levenshtein <= max_distance           -> "fuzzy"
```

- Steps 2-4 yielding several candidates give `match_type = "ambiguous"`
  and `code = NA`, with every candidate listed.
- When `parent` is supplied, candidates from steps 2-4 are filtered by
  parent code; resolution to exactly one keeps that step's `match_type`.
  A name that exists but not under the requested parent reports `"none"`
  with the units it does name, so the message can say where it is.
- `"Tan Phu, Dong Nai"` and `"Tan Phu (Dong Nai)"` are split **only
  when the trailing part is an existing province name**, mirroring the
  `isParentName()` guard in `maps.js`. Without that guard, strings such
  as `"Xuan Loc, khu 3"` are mis-split.
- **Step 5 never resolves.** `code` stays `NA` and candidates are
  reported. This is what "strict is preserved" means in code.

### 5.3 `province_code()`

Unchanged return value; the error message gains candidates:

```
Error: Unknown province or municipality: "Hanoii", "Cantho".
  "Hanoii" - did you mean "Ha Noi" (01)?
  "Cantho" - did you mean "Can Tho" (92)?
Use vn_match() to inspect all matches without raising an error.
```

Implemented by calling `vn_match()` internally and rendering the `NA`
rows. Because step 6 does not resolve, the set of inputs that succeed
is byte-identical to the current implementation.

### 5.4 `commune_code()`

`.match_units()` (`R/vn-map.R`) currently ORs `%in%` comparisons across
`code`, `name_vi` and `name_en`, so duplicate commune names silently
return several rows. A caller cannot tell how many polygons
`vn_map("communes", include = "Tan Phu")` returned or why.

```r
commune_code(x, province = NULL)
```

- Duplicates without `province` raise an error listing every candidate,
  each qualified by its province.
- `"Tan Phu, Dong Nai"` is accepted.
- `.match_units()` is reimplemented on top of this, making
  `vn_map("communes", include = )` explicit about ambiguity.

A separate function rather than `geography = "communes"` on
`province_code()`: the parent hint is close to mandatory at commune
level and does not belong in a function named for provinces.

### 5.5 Geography confusion detection

When `province_code()` fails, retry the unmatched names against the
other geography. If most of them resolve there, say so:

```
Error: Unknown province or municipality: "Bac Giang", "Vinh Phuc", "Ha Tay", ...
  12 of 14 unmatched names match the pre-July-2025 geography.
  Did you mean geography = "provinces_63"?
```

Equivalent to `detectLevel()` in `maps.js`. A few lines of code against
the mistake most likely to be made by a caller of `plot_vnmap(data = )`.

### 5.6 Tests

`tests/testthat/test-match.R` with a golden fixture at
`tests/testthat/fixtures/name-cases.csv`
(`input, geography, parent, expect_code, expect_type`). Cases:

- names with, without and with incorrect diacritics
- the several written forms of Thanh pho Ho Chi Minh
- regression cases for the prefix defect: `Tinh Bien`, `Thanh Phong`
- duplicate commune names: ambiguity detected, resolved by `parent`,
  resolved by the `"name, province"` form
- fuzzy candidates are reported while `code` stays `NA`
- invariant: no two communes within one province share a `.vn_key()`

The last case pairs with the manifest tests below: both assert
properties of the bundled data rather than of the code alone.

## 6. Design B: machine-readable provenance

### 6.1 `inst/extdata/manifest.json`

```json
{
  "schema_version": 1,
  "package_version": "0.2.0",
  "layers": [{
    "layer": "communes",
    "file": "extdata/communes.rds",
    "md5": "...",
    "n_features": 3321,
    "geometry_vintage": "2026-07-25",
    "geometry_accuracy": "generalized to 100 m",
    "crs": "EPSG:3405",
    "administrative_basis": "Decision 19/2025/QD-TTg, effective 2025-07-01",
    "source": {
      "name": "Vietnamese Provinces Database",
      "url": "https://github.com/thanglequoc/vietnamese-provinces-database",
      "ref": "cd58063299585146ded3981f2272946ef19ced54",
      "license": "MIT",
      "upstream": "Viet Nam Administrative Units Reference Map"
    },
    "build_script": "data-raw/build_communes.R",
    "last_updated": "..."
  }]
}
```

Key names follow `india-geodata` where they overlap (`sources`,
`license`, `coordinate_system`, `storage`, `last_updated`). The fields
`geometry_vintage`, `geometry_accuracy`, `administrative_basis` and
`build_script` are specific to this package and have no counterpart
there; they are the information `vnmap` already tracks and should not
lose by adopting someone else's schema.

Exposed through one function:

```r
vn_provenance(layer = NULL)   # data frame; all layers when layer is NULL
```

### 6.2 Tests are the point

`validate-metadata.py` checks that metadata is well-formed. For a
package that ships its data, checking metadata *against the artifacts*
is worth more. `tests/testthat/test-manifest.R`:

1. the JSON parses and every required key is present
2. every `layers[].file` exists
3. each `.rds` MD5 matches the manifest
4. each `.rds` row count matches `n_features`
5. no file under `inst/extdata/` is missing from the manifest
6. `package_version` matches `DESCRIPTION`

Checks 3 to 5 make a stale manifest a CI failure rather than a silent
inaccuracy. `R CMD build` copies `inst/` verbatim, so the checksums are
stable on CRAN.

### 6.3 Relationship to `inst/COPYRIGHTS`

`inst/COPYRIGHTS` stays: it is the conventional location and CRAN reads
it. The manifest duplicates part of it. Generating both from a single
`data-raw/sources.csv` was considered and deferred; the manifest is
hand-maintained, with only `md5` and `n_features` filled in by
`make manifest`. Revisit if the two records drift.

### 6.4 Incidental fixes

- `inst/CITATION` states version 0.1.0 while `DESCRIPTION` states
  0.2.0. Use `meta$Version` so it tracks automatically.
- No `CITATION.cff`, so GitHub shows no "Cite this repository" button.
  Add one, listing geoBoundaries, the Vietnamese Provinces Database,
  OpenStreetMap and the General Statistics Office under `references`,
  following the pattern in `india-geodata`.
- Add `vn_match`, `commune_code` and `vn_provenance` to `_pkgdown.yml`.

## 6a. Changed during implementation

Two parts of the design above did not survive contact with the data.

**The word-order stage was dropped.** `maps.js` sorts words apart so
that `24 Parganas North` matches `North 24 Parganas`. That is a real
Indian naming pattern; Vietnamese place names have a fixed word order,
and the stage only manufactured matches. It resolved `"Noi Ha"` to Ha
Noi, which is wrong. Removing it also keeps `province_code()`'s
success/failure boundary where it was, which the accepted design
required. Not every borrowed rule transfers, and this one did not.

**`alias` is not a `match_type`.** Whether a value matched the canonical
name or some other alias is orthogonal to how it was normalised, and
collapsing the two into one enum loses information. `match_type` now
reports the normalisation step only, and a `matched_on` column gives the
alias text that produced the hit, which is strictly more than the
original design carried.

**The manifest needed a `storage` field.** The design assumed every
bundled dataset could be checksummed after installation. Two cannot:
`LazyData: true` folds the datasets under `data/` into the lazy-load
database, so they no longer exist as files once installed. Each entry now
carries `storage`, `"extdata"` or `"lazydata"`, borrowed from the same
field in `india-geodata`; checksums are verified for the former and row
counts for both. This was found by the tests, which is the argument for
writing them.

One asymmetry is worth recording. The geography-confusion check in 5.5
is written symmetrically but fires in practice in one direction only:
the 2025 reform kept the surviving unit names, so 29 of the 63 former
names are gone from the current geography while just one current name,
`Hue`, is absent from the former one --- below the two-name threshold.
The reverse branch is retained because it is cheap and a later reform
could change the picture, but it is effectively unreachable today.

## 7. Decisions

| Question | Decision |
|---|---|
| Scope of this round | Name matching and provenance manifest |
| Fuzzy matching | Strict preserved. Edit distance appears in error messages only; `code` stays `NA`. Full backward compatibility |
| Commune lookup API | New exported `commune_code(x, province = )`; `province_code()` stays provincial |
| Provenance format | Hand-maintained `manifest.json`; `md5` and `n_features` generated. Overlap with `COPYRIGHTS` accepted for now |
| `communes_63` / `districts_63` | Move to GitHub Releases plus a caching `vn_download_layer()`. Deferred, direction agreed |
| Browser map maker | Deferred. If taken up, extract the alias table to JSON first so R and JavaScript share one source |

## 8. Implementation order

Workstreams A and B are independent and can proceed in parallel.

**A - name matching**

1. Three-stage normalisation; fix the prefix defect
2. `vn_match()` cascade, parent filtering, `"name, parent"` splitting
3. Candidates in `province_code()` errors; return value unchanged
4. `commune_code()`; reimplement `.match_units()` on it
5. Geography confusion detection
6. `test-match.R` and the golden fixture

Steps 1 to 3 are independently valuable and can ship without 4 onwards.

**B - provenance**

7. Hand-write `manifest.json` for the bundled datasets (eleven, not nine:
   the two published statistical tables under `data/` carry provenance
   worth recording too)
8. `data-raw/build_manifest.R` and a `manifest` target in `Makefile`
9. Export `vn_provenance()`
10. `test-manifest.R`
11. `inst/CITATION` version, `CITATION.cff`, `_pkgdown.yml` entries

## 9. Source

Surveyed at commit `0e378cc` of `https://github.com/yashveeeeeeer/india-geodata`
on 2026-09-10. Licensed CC BY 4.0. No code or data from that repository
is copied into `vnmap`; only the design approaches described above are
adopted.
