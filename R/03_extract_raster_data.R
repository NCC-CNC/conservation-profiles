# Compute the area (ha) of "1" cells in a binary raster that fall inside a boundary polygon.
# Raster must be coded 1/0 or 1/NoData for the sum to give a meaningful area.

source("R/fct_read_feature.R")
source("R/fct_read_raster.R")

intersect_raster_value <- function(rast_path, boundary_sf) {
  r <- read_raster(rast_path)
  vals <- exactextractr::exact_extract(
    x = r,
    y = boundary_sf,
    fun = "sum",
    coverage_area = TRUE
  )
  round(sum(vals, na.rm = TRUE) / 10000, 4) # m² to ha
}

raster_intersect <- function(raster_names, raster_paths, project_path){

  project_sf <- read_feature(project_path) |> sf::st_union() |> sf::st_as_sf()

  results <- list()
  for (i in 1:length(raster_paths)) {

    cat(sprintf("Processing %s - %s\n", raster_names[i], raster_paths[i]))

    project_value <- intersect_raster_value(raster_paths[i], project_sf)
  
    results[[i]] <- data.frame(
      Dataset = raster_names[i],
      Path = raster_paths[i],
      Project_value = project_value,
      check.names = FALSE
    )
  }
  
  # Stack the per-row data.frames in `results` into a single data.frame
  return(do.call(rbind, results))
}

# Sum cell values weighted by coverage fraction (for continuous rasters, e.g. carbon tonnes per cell).
# Returns a rounded integer — change rounding if sub-unit precision is needed.
intersect_raster_cell_sum <- function(rast_path, boundary_sf) {
  r <- read_raster(rast_path)
  round(exactextractr::exact_extract(r, boundary_sf, fun = "sum"), 0)
}

raster_cell_sum_intersect <- function(raster_names, raster_paths, project_path) {
  project_sf <- read_feature(project_path) |> sf::st_union() |> sf::st_as_sf()
  results <- list()
  for (i in seq_along(raster_paths)) {
    cat(sprintf("Processing %s - %s\n", raster_names[i], raster_paths[i]))
    project_value <- intersect_raster_cell_sum(raster_paths[i], project_sf)
    results[[i]] <- data.frame(Dataset = raster_names[i], Path = raster_paths[i], Project_value = project_value, check.names = FALSE)
  }
  do.call(rbind, results)
}
