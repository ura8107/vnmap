# Assets for `ura8107/vietnam-calendar`

These files are the stable handoff from `vnmap` to the calendar app:

- `vietnam-provinces-34.geojson`: 34 current provincial-level boundaries in
  GeoJSON / WGS84 (EPSG:4326), produced by `vn_map(crs = 4326)`.
- `province-stats-2024.csv`: the bundled 34-row `province_stats_2024` dataset.
  It is included so app demos do not need to parse R data files.
- `grdp-per-capita-2024.svg`: a lightweight preview generated through
  `plot_vnmap()` using `grdp_per_capita_million_vnd`.
- `checksums.md5`: content fingerprints for the three distributable files.

## Rebuild and verify

From the `vnmap` repository root, run:

```sh
make calendar-assets
make verify-calendar-assets
```

The Make target installs the working tree into `.build/calendar-library`, then
runs the exporter against that installed package. This ensures the GeoJSON and
SVG use the same public `vn_map()` and `plot_vnmap()` behavior that consumers
receive. Inputs are sorted by numeric administrative code; locale, timezone,
coordinate precision, dimensions, palette, and field order are fixed.

Commit all four generated files together. A changed checksum is expected only
when bundled boundaries, statistics, plotting code, or renderer versions
change. Build with the project's pinned R/package environment in CI when byte-
identical output across machines is required.

## Consume from `ura8107/vietnam-calendar`

Copy this directory into the app's static assets directory (for example,
`public/data/vietnam/`) without renaming individual files. Treat `code` as a
string: values such as `"01"` and `"04"` must retain their leading zero.

```sh
mkdir -p public/data/vietnam
cp /path/to/vnmap/app-assets/vietnam-calendar/{vietnam-provinces-34.geojson,province-stats-2024.csv,grdp-per-capita-2024.svg,checksums.md5} public/data/vietnam/
```

Fetch the boundary layer directly in browser code:

```js
const response = await fetch('/data/vietnam/vietnam-provinces-34.geojson');
if (!response.ok) throw new Error(`Boundary load failed: ${response.status}`);
const provinces = await response.json();

for (const feature of provinces.features) {
  // Stable join key for calendar events, stats, and map interactions.
  const provinceCode = feature.properties.code;
}
```

The GeoJSON feature properties are `code`, `iso`, `name_vi`, `name_en`, and
`type`; geometry is `Polygon` or `MultiPolygon` longitude/latitude coordinates.
Join CSV rows to features with the exact string equality
`row.code === feature.properties.code`. Do not join on display names and do not
project the coordinates before passing them to browser mapping libraries that
expect GeoJSON WGS84.

For a no-JavaScript preview, use:

```html
<img
  src="/data/vietnam/grdp-per-capita-2024.svg"
  alt="Map of 2024 GRDP per capita across Viet Nam's 34 current provincial units"
  width="499"
  height="614"
>
```

The 2024 statistics predate the July 2025 geography. Merged-unit population and
area are sums, density is recalculated, and GRDP per capita is population-
weighted. Present those values as estimates and retain the year and preliminary
status in UI copy.
