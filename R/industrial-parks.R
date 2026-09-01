.ip_categories <- c("industrial_park", "export_processing_zone",
                    "hi_tech_park", "industrial_cluster")
.ip_register <- c("industrial_park", "export_processing_zone")
.ip_statuses <- c("operational", "under_construction",
                  "established_not_started", "unknown")

# Columns a user may supply for a park. Everything else in the layer records
# where a value came from and is therefore not user-writable.
.ip_editable <- c("name_vi", "name_en", "aliases", "category", "status",
                  "area_ha", "developer", "website", "established_year",
                  "occupancy_rate", "notes")
.ip_locators <- c("province_code", "longitude", "latitude")

.ip_read <- function() {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required to load industrial park geometry. ",
         "Install it with install.packages(\"sf\").", call. = FALSE)
  }
  file <- system.file("extdata", "industrial_parks.rds", package = "vnmap")
  if (!nzchar(file)) {
    stop("Bundled industrial park data could not be found.", call. = FALSE)
  }
  readRDS(file)
}

.ip_check_categories <- function(category) {
  if (is.null(category)) return(.ip_categories)
  bad <- setdiff(category, .ip_categories)
  if (length(bad)) {
    stop("Unknown industrial park category: ", paste(bad, collapse = ", "),
         ". Use one or more of ", paste(.ip_categories, collapse = ", "),
         ", or NULL for every category.", call. = FALSE)
  }
  category
}

#' Obtain industrial park map data
#'
#' Returns Vietnamese industrial parks with the best redistributable geometry
#' available for each park. Polygon boundaries are retained where a mapped site
#' boundary is available; otherwise a representative point is used.
#'
#' The bundled layer is a mapped subset, not the national register: see
#' [industrial_parks_data] for the coverage gap against the official count of
#' established parks. Use `attributes` to supply parks or attribute values the
#' snapshot does not carry, and [industrial_parks_template()] to produce a file
#' in the expected shape.
#'
#' @param province Optional current or pre-2025 provincial identifiers.
#' @param category Designations to return. Defaults to the two designations
#'   counted in the national industrial-park register, `"industrial_park"`
#'   (khu cong nghiep) and `"export_processing_zone"` (khu che xuat). Also
#'   accepts `"hi_tech_park"` and `"industrial_cluster"`, which are separate
#'   legal categories, or `NULL` for every category.
#' @param status Optional status values: `"operational"`,
#'   `"under_construction"`, `"established_not_started"`, or `"unknown"`.
#' @param include Optional park identifiers or Vietnamese/English names.
#' @param geometry One of `"best"`, `"polygon"`, or `"point"`. `"point"`
#'   converts polygon sites to points guaranteed to lie on their surfaces.
#' @param attributes Optional user-supplied basic information: a data frame, or
#'   a path to a CSV file, with an `id` column. See
#'   [industrial_parks_template()].
#' @param crs Coordinate reference system understood by [sf::st_transform()].
#' @return An `sf` object. See [industrial_parks_data] for data provenance.
#' @seealso [industrial_parks_template()] and [write_industrial_parks()] for
#'   reading and writing basic information, [geom_industrial_parks()] for
#'   mapping.
#' @examples
#' parks <- industrial_parks(province = "Dong Nai")
#' points <- industrial_parks(geometry = "point", crs = 4326)
#' clusters <- industrial_parks(category = "industrial_cluster")
#' @export
industrial_parks <- function(province = NULL, category = .ip_register,
                             status = NULL, include = NULL,
                             geometry = c("best", "polygon", "point"),
                             attributes = NULL, crs = vnmap_crs()) {
  geometry <- match.arg(geometry)
  category <- .ip_check_categories(category)
  parks <- .ip_read()
  if (!is.null(attributes)) parks <- .ip_apply_attributes(parks, attributes)

  if (!is.null(province)) {
    current <- tryCatch(province_code(province), error = function(e) NULL)
    former <- tryCatch(province_code(province, "provinces_63"), error = function(e) NULL)
    if (is.null(current) && is.null(former)) {
      stop("Unknown province or municipality: ", paste(province, collapse = ", "), call. = FALSE)
    }
    keep <- rep(FALSE, nrow(parks))
    if (!is.null(current)) keep <- keep | parks$province_code %in% current
    if (!is.null(former)) keep <- keep | parks$former_province_code %in% former
    parks <- parks[keep, , drop = FALSE]
  }
  parks <- parks[parks$category %in% category, , drop = FALSE]
  if (!is.null(status)) {
    bad <- setdiff(status, .ip_statuses)
    if (length(bad)) stop("Unknown industrial park status: ", paste(bad, collapse = ", "), call. = FALSE)
    parks <- parks[parks$status %in% status, , drop = FALSE]
  }
  if (!is.null(include)) {
    keys <- .vn_key(include)
    alias_hit <- vapply(strsplit(parks$aliases, "\\|"), function(x) {
      any(.vn_key(x) %in% keys)
    }, logical(1))
    keep <- .vn_key(parks$id) %in% keys | .vn_key(parks$name_vi) %in% keys |
      .vn_key(parks$name_en) %in% keys | alias_hit
    parks <- parks[keep, , drop = FALSE]
  }
  if (geometry == "polygon") {
    parks <- parks[parks$geometry_type == "polygon", , drop = FALSE]
  } else if (geometry == "point" && nrow(parks)) {
    sf::st_geometry(parks) <- sf::st_geometry(
      suppressWarnings(sf::st_point_on_surface(parks))
    )
    parks$geometry_type <- "point"
  }
  if (!nrow(parks)) stop("No industrial parks matched the requested filters.", call. = FALSE)
  sf::st_transform(parks, crs)
}

#' Write a basic-information template for industrial parks
#'
#' Produces the table that [industrial_parks()] accepts through its
#' `attributes` argument: one row per park, an `id` column, and the columns a
#' user may fill in. Rows carrying an `id` that is already in the bundled layer
#' update that park; rows carrying a new `id` add a park, and must supply
#' `name_vi`, `province_code`, `longitude`, and `latitude`.
#'
#' Only non-empty values are applied, so an untouched template changes nothing.
#'
#' @param path Optional file to write. The extension selects the format:
#'   `.csv` (default) or `.tsv`. When `NULL` the table is only returned.
#' @param blank When `TRUE`, the editable columns are written empty so that the
#'   file records user-supplied values only. When `FALSE`, the bundled values
#'   are written as a starting point.
#' @param ... Filters passed to [industrial_parks()].
#' @return A data frame, invisibly when `path` is supplied.
#' @examples
#' template <- industrial_parks_template(province = "Dong Nai")
#' head(template[c("id", "name_vi", "status", "area_ha")])
#' @export
industrial_parks_template <- function(path = NULL, blank = FALSE, ...) {
  parks <- industrial_parks(..., geometry = "point", crs = 4326)
  coords <- sf::st_coordinates(parks)
  out <- sf::st_drop_geometry(parks)
  extra <- setdiff(.ip_editable, names(out))
  for (column in extra) out[[column]] <- NA
  out <- out[c("id", .ip_editable, "province_code")]
  out$longitude <- coords[, "X"]
  out$latitude <- coords[, "Y"]
  if (blank) for (column in .ip_editable) out[[column]] <- NA
  row.names(out) <- NULL
  if (is.null(path)) return(out)
  separator <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  utils::write.table(out, path, sep = separator, row.names = FALSE,
                     qmethod = "double", na = "")
  invisible(out)
}

.ip_apply_attributes <- function(parks, attributes) {
  if (is.character(attributes)) {
    if (length(attributes) != 1L || !file.exists(attributes)) {
      stop("`attributes` must be a data frame or the path to an existing file.",
           call. = FALSE)
    }
    separator <- if (grepl("\\.tsv$", attributes, ignore.case = TRUE)) "\t" else ","
    attributes <- utils::read.delim(attributes, sep = separator,
                                    stringsAsFactors = FALSE, na.strings = c("", "NA"))
  }
  attributes <- as.data.frame(attributes, stringsAsFactors = FALSE)
  if (!"id" %in% names(attributes)) {
    stop("`attributes` needs an `id` column identifying each park.", call. = FALSE)
  }
  attributes$id <- trimws(as.character(attributes$id))
  attributes <- attributes[nzchar(attributes$id) & !is.na(attributes$id), , drop = FALSE]
  if (anyDuplicated(attributes$id)) {
    stop("`attributes` repeats these ids: ",
         paste(unique(attributes$id[duplicated(attributes$id)]), collapse = ", "),
         call. = FALSE)
  }
  unknown <- setdiff(names(attributes), c("id", .ip_editable, .ip_locators))
  if (length(unknown)) {
    stop("`attributes` has columns that are not user-writable: ",
         paste(unknown, collapse = ", "), ". Writable columns are ",
         paste(c(.ip_editable, .ip_locators), collapse = ", "), ".", call. = FALSE)
  }
  if ("category" %in% names(attributes)) {
    supplied <- as.character(attributes$category)
    .ip_check_categories(unique(supplied[!is.na(supplied)]))
  }
  if ("status" %in% names(attributes)) {
    supplied <- as.character(attributes$status)
    bad <- setdiff(supplied[!is.na(supplied)], .ip_statuses)
    if (length(bad)) {
      stop("`attributes` uses unknown status values: ", paste(bad, collapse = ", "),
           call. = FALSE)
    }
  }

  new <- !attributes$id %in% parks$id
  # A column the layer does not carry - occupancy, a survey note - is created
  # with the type the user supplied it in, not coerced to the layer's types.
  for (column in setdiff(names(attributes), c("id", .ip_locators))) {
    if (!column %in% names(parks)) {
      parks[[column]] <- rep(attributes[[column]][NA_integer_], nrow(parks))
    }
  }
  if (any(new)) parks <- .ip_add_parks(parks, attributes[new, , drop = FALSE])

  update <- attributes[!new, , drop = FALSE]
  if (nrow(update)) {
    row <- match(update$id, parks$id)
    changed <- rep(FALSE, nrow(update))
    for (column in setdiff(names(update), c("id", .ip_locators))) {
      value <- update[[column]]
      supplied <- !is.na(value) & (!is.character(value) | nzchar(as.character(value)))
      if (!any(supplied)) next
      parks[[column]][row[supplied]] <- .ip_coerce(value[supplied],
                                                   parks[[column]])
      changed <- changed | supplied
    }
    parks$attribute_source[row[changed]] <- "user"
  }
  parks <- parks[order(parks$province_code, parks$category, parks$name_vi), ,
                 drop = FALSE]
  row.names(parks) <- NULL
  parks
}

.ip_coerce <- function(value, target) {
  if (is.numeric(target)) as.numeric(value) else as.character(value)
}

.ip_add_parks <- function(parks, added) {
  required <- c("name_vi", "province_code", "longitude", "latitude")
  missing <- setdiff(required, names(added))
  if (length(missing)) {
    stop("New parks need ", paste(required, collapse = ", "), "; missing ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  }
  incomplete <- Reduce(`|`, lapply(added[required], is.na))
  if (any(incomplete)) {
    stop("These new parks are missing a name, province or coordinate: ",
         paste(added$id[incomplete], collapse = ", "), call. = FALSE)
  }
  frame <- parks[rep(NA_integer_, nrow(added)), , drop = FALSE]
  frame$id <- added$id
  for (column in intersect(names(added), .ip_editable)) {
    frame[[column]] <- .ip_coerce(added[[column]], parks[[column]])
  }
  frame$province_code <- province_code(as.character(added$province_code))
  frame$province_en <- province_info()$name_en[
    match(frame$province_code, province_info()$code)]
  frame$category[is.na(frame$category)] <- "industrial_park"
  frame$status[is.na(frame$status)] <- "unknown"
  frame$geometry_type <- "point"
  frame$location_accuracy <- "user_supplied"
  frame$part_count <- 1L
  frame$source <- "user"
  frame$attribute_source <- "user"
  sf::st_geometry(frame) <- sf::st_sfc(
    lapply(seq_len(nrow(added)), function(i) {
      sf::st_point(c(added$longitude[i], added$latitude[i]))
    }), crs = 4326)
  rbind(parks, sf::st_transform(frame, sf::st_crs(parks)))
}

#' Write industrial park data to a file
#'
#' Exports an industrial park layer for use outside R. CSV output drops the
#' geometry column and adds representative `longitude` and `latitude` columns,
#' so it round-trips through [industrial_parks()]'s `attributes` argument;
#' GeoJSON and GeoPackage output keep the mapped boundaries.
#'
#' @param x An `sf` object from [industrial_parks()].
#' @param path Output file. The extension selects the format unless `format`
#'   is given.
#' @param format One of `"csv"`, `"geojson"`, or `"gpkg"`.
#' @param ... Passed to [sf::st_write()] for the spatial formats.
#' @return `path`, invisibly.
#' @examples
#' parks <- industrial_parks(province = "Dong Nai")
#' file <- tempfile(fileext = ".csv")
#' write_industrial_parks(parks, file)
#' @export
write_industrial_parks <- function(x, path, format = NULL, ...) {
  if (!inherits(x, "sf")) stop("`x` must be an sf object.", call. = FALSE)
  if (is.null(format)) {
    format <- tolower(sub("^.*\\.", "", path))
    if (identical(format, "json")) format <- "geojson"
  }
  format <- match.arg(format, c("csv", "geojson", "gpkg"))
  if (identical(format, "csv")) {
    geographic <- sf::st_transform(x, 4326)
    coords <- sf::st_coordinates(suppressWarnings(sf::st_point_on_surface(geographic)))
    out <- sf::st_drop_geometry(geographic)
    out$longitude <- coords[, "X"]
    out$latitude <- coords[, "Y"]
    utils::write.csv(out, path, row.names = FALSE, na = "")
  } else {
    sf::st_write(x, path, delete_dsn = file.exists(path), quiet = TRUE, ...)
  }
  invisible(path)
}

#' Add industrial parks to a ggplot map
#'
#' Creates `ggplot2` layers that can be added directly to [plot_vnmap()].
#' @inheritParams industrial_parks
#' @param data Optional industrial park `sf` object.
#' @param polygon_fill,polygon_colour Fill and outline colours for polygons.
#' @param point_colour Colour for representative points.
#' @param alpha Polygon opacity.
#' @param linewidth Polygon outline width.
#' @param point_size Point size.
#' @return A list of `ggplot2` layers.
#' @examples
#' plot_vnmap() + geom_industrial_parks(point_colour = "#b2182b")
#' @export
geom_industrial_parks <- function(data = NULL, province = NULL,
                                  category = .ip_register, status = NULL,
                                  include = NULL,
                                  geometry = c("best", "polygon", "point"),
                                  attributes = NULL, crs = vnmap_crs(),
                                  polygon_fill = "#e69f00",
                                  polygon_colour = "#9a6700",
                                  point_colour = "#b2182b", alpha = 0.35,
                                  linewidth = 0.25, point_size = 1.5) {
  geometry <- match.arg(geometry)
  if (is.null(data)) {
    data <- industrial_parks(province, category, status, include, geometry,
                             attributes, crs)
  } else {
    if (!inherits(data, "sf")) stop("`data` must be an sf object.", call. = FALSE)
    data <- sf::st_transform(data, crs)
    type <- tolower(as.character(sf::st_geometry_type(data)))
    if (geometry == "polygon") data <- data[type %in% c("polygon", "multipolygon"), , drop = FALSE]
    if (geometry == "point") {
      sf::st_geometry(data) <- sf::st_geometry(
        suppressWarnings(sf::st_point_on_surface(data))
      )
    }
  }
  type <- tolower(as.character(sf::st_geometry_type(data)))
  polygons <- data[type %in% c("polygon", "multipolygon"), , drop = FALSE]
  points <- data[type %in% c("point", "multipoint"), , drop = FALSE]
  layers <- list()
  if (nrow(polygons)) layers <- c(layers, list(ggplot2::geom_sf(
    data = polygons, inherit.aes = FALSE, fill = polygon_fill,
    colour = polygon_colour, alpha = alpha, linewidth = linewidth)))
  if (nrow(points)) layers <- c(layers, list(ggplot2::geom_sf(
    data = points, inherit.aes = FALSE, colour = point_colour, size = point_size)))
  layers
}
