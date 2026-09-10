# Vietnam industrial-site dataset — 2026-09-10

The map covers 429 sites: 306 industrial parks/EPZ, 118 industrial clusters,
and 5 hi-tech parks. This is not a complete verified national legal register.

- `mapped-sites.csv`: every mapped site with WGS84 coordinates and provenance.
- `industrial-parks.geojson`: mapped polygons and locality points.
- `industrial-parks-map.png`: category-colored distribution map.
- `source-catalogue.csv`: all 1,651 source rows, including 1,356 unresolved rows.
- `province-source-coverage.csv`: exact row coverage for 34 provinces plus unknown.
- `coordinate-conflicts.csv`: 14 source-coordinate/province conflicts for review.
- `collection-audit.md`: Japanese audit with methods, Git state and remaining work.

Source rows are not unique parks. Missing coordinates remain missing. Planned
projects and unverified legal status must not be interpreted as operational
parks. OpenStreetMap-derived coordinates/geometry are subject to ODbL 1.0;
retain OpenStreetMap contributor attribution in maps and derived works.
