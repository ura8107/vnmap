library(sf)

pbf <- Sys.getenv("VNMAP_OSM_PBF",
                  file.path(tempdir(), "vietnam-260810.osm.pbf"))
expected <- "8d79d8ca13e45a733d15504b9a9c84dc"
stopifnot(file.exists(pbf), unname(tools::md5sum(pbf)) == expected)
query <- paste0(
  "SELECT * FROM lines WHERE ",
  "highway IN ('motorway','trunk','construction','proposed') OR ",
  "railway IN ('rail','construction','proposed','disused','abandoned') OR ",
  "other_tags LIKE '%\"ref\"=>\"QL%' OR other_tags LIKE '%\"ref\"=>\"CT%'"
)
x <- st_read(pbf, query = query, quiet = TRUE)
stopifnot(nrow(x) > 0L, all(st_geometry_type(x) == "LINESTRING"))
saveRDS(x, "data-raw/source/osm-trunk-lines-2026-08-10.rds",
        compress = "xz", version = 3)
