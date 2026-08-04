source("R/fct_read_feature.R")

# Intersects a with b and dissolves to a single feature. Returns a zero-row sf
# object (same CRS as b) instead of erroring when there's no overlap, so
# downstream area/raster extractions can treat "0 rows" as "0 area" uniformly.
safe_intersection <- function(a, b) {
  result <- tryCatch(
    sf::st_intersection(a, b),
    error = function(e) sf::st_sf(geometry = sf::st_sfc(crs = sf::st_crs(b)))
  )
  if (nrow(result) == 0) return(result)
  sf::st_union(result) |> sf::st_as_sf()
}

# Returns a vector layer's native CRS without reading its features --
# wkt_filter (used below) is evaluated in the *layer's own* CRS, not the
# filter geometry's, so the filter bbox has to be expressed in that CRS.
# do_count = FALSE matters here: st_layers() otherwise counts every feature
# in the layer, which is a multi-minute full scan on a national-scale layer
# (e.g. tens of millions of features) -- we only need the CRS.
vector_layer_crs <- function(feature_path) {
  if (grepl("\\.gdb/", feature_path)) {
    parts <- strsplit(feature_path, "\\.gdb/")[[1]]
    info  <- sf::st_layers(paste0(parts[1], ".gdb"), do_count = FALSE)
    info$crs[[which(info$name == parts[2])]]
  } else {
    sf::st_layers(feature_path, do_count = FALSE)$crs[[1]]
  }
}

# Reads feature_path pre-filtered to landscape_sf's extent, then reprojects
# the (now small) result to landscape_sf's CRS.
read_landscape_filtered <- function(feature_path, landscape_sf) {
  bbox <- sf::st_bbox(sf::st_transform(landscape_sf, vector_layer_crs(feature_path)))
  read_feature(feature_path, bbox = bbox) |> sf::st_transform(sf::st_crs(landscape_sf))
}

# Loads the geometries shared by the custom-landscape ERAP row (05) and
# species table (04) builders: the dissolved landscape boundary, the
# protected areas within it, and the WTW solution within it. Computed once
# and threaded into both consumers so the (often national-scale) protected/
# WTW vector layers only get read and intersected a single time per run.
#
# protected_vector_path/wtw_vector_path are read with a bounding-box
# pre-filter (read_feature()'s bbox arg, applied at the GDAL level via
# wkt_filter) instead of loading the full national layer -- these can run
# into the tens of millions of features (e.g. a national waterbody layer),
# and reading + dissolving one in full before intersecting with a small
# landscape polygon is impractically slow.
get_custom_landscape_geoms <- function(custom_landscape) {
  landscape_sf <- read_feature(custom_landscape$landscape_path) |> sf::st_union() |> sf::st_as_sf()

  protected_sf <- read_landscape_filtered(custom_landscape$protected_vector_path, landscape_sf) |> sf::st_union() |> sf::st_as_sf()
  wtw_sf       <- read_landscape_filtered(custom_landscape$wtw_vector_path, landscape_sf) |> sf::st_union() |> sf::st_as_sf()

  list(
    landscape_sf              = landscape_sf,
    protected_in_landscape_sf = safe_intersection(protected_sf, landscape_sf),
    wtw_in_landscape_sf       = safe_intersection(wtw_sf, landscape_sf)
  )
}
