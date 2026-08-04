source("R/fct_read_feature.R")

# Reprojects a single vector path to ref_crs if it doesn't already match,
# writing a scratch shapefile next to the source layer and warning the user.
# Returns the original path unchanged when the projections already match.
reproject_if_needed <- function(path, ref_crs, label) {
  feature_sf <- read_feature(path)

  if (terra::same.crs(sf::st_crs(feature_sf)$wkt, ref_crs))
    return(path)

  if (grepl("\\.gdb/", path)) {
    parts   <- strsplit(path, "\\.gdb/")[[1]]
    src_dir <- dirname(paste0(parts[1], ".gdb"))
    layer   <- parts[2]
  } else {
    src_dir <- dirname(path)
    layer   <- tools::file_path_sans_ext(basename(path))
  }

  scratch_path <- file.path(src_dir, paste0(layer, "_reprojected.shp"))

  warning(
    label, " is not in the Albers projection of habitat_forest. ",
    "Reprojecting on the fly and writing scratch file: ", scratch_path,
    call. = FALSE
  )

  feature_sf <- sf::st_transform(feature_sf, ref_crs)
  sf::st_write(feature_sf, scratch_path, delete_layer = TRUE, quiet = TRUE)

  scratch_path
}

# Ensures the project boundary -- and, for custom landscapes, the user-supplied
# landscape boundary -- share the Albers projection of habitat_forest,
# reprojecting on the fly where needed (see reproject_if_needed()). Other
# custom_landscape paths (protected/WTW vectors, protected grid, species
# metadata) are not checked -- those are supplied pre-projected, unlike
# project_path/landscape_path which come directly from users.
reproject_project_path <- function(cfg) {
  ref_crs <- terra::crs(terra::rast(cfg$habitat_raster$habitat_forest))

  cfg$project$project_path <- reproject_if_needed(cfg$project$project_path, ref_crs, "project_path")

  custom <- cfg$custom_landscape
  if (!is.null(custom$landscape_path) && nzchar(custom$landscape_path))
    cfg$custom_landscape$landscape_path <- reproject_if_needed(custom$landscape_path, ref_crs, "custom_landscape$landscape_path")

  cfg
}
