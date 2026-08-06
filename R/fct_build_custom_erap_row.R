source(file.path(CODE_DIR, "R/fct_read_feature.R"))
source(file.path(CODE_DIR, "R/03_extract_raster_data.R"))

# Builds a one-row ERAP-equivalent data.frame for a user-supplied custom
# landscape, by intersecting it against the same habitat/pressure/WTW/
# protected-areas data configured in setup.toml, instead of looking up a
# pre-computed row from ERAP_ecoregions.gdb. Column set matches exactly what
# build_profile_tab() consumes post-lookup (erap_header_cols/habitat_area_cols/
# habitat_linear_cols/pressure_cols/intactness_cols in 05_build_profile_excel.R)
# -- a custom landscape is always a single dissolved polygon, so
# combine_erap_rows()'s raw _km2 breakdown columns (needed only to recombine
# multiple ecoregions) aren't required here. Note this only produces landscape
# stats -- ECOREGION/REGION_NAM/ECOZONE/ZONE_NAME etc are always the project's
# own real ecoregion attributes, handled uniformly in build_profile_tab()
# regardless of whether a custom landscape is set (see get_overlapping_ecoregions()).
build_custom_erap_row <- function(cfg, geoms) {

  print("building custom landscape assessment...")

  custom <- cfg$custom_landscape

  landscape_sf              <- geoms$landscape_sf
  protected_in_landscape_sf <- geoms$protected_in_landscape_sf
  wtw_in_landscape_sf       <- geoms$wtw_in_landscape_sf

  landscape_km2 <- as.numeric(sf::st_area(landscape_sf)) / 1e6
  landscape_ha  <- landscape_km2 * 100

  protected_km2 <- if (nrow(protected_in_landscape_sf) > 0)
    sum(as.numeric(sf::st_area(protected_in_landscape_sf))) / 1e6 else 0
  has_wtw_vector <- nrow(wtw_in_landscape_sf) > 0

  # header protected/WTW figures -- per erap-deer-code's
  # 1e_prioritizr_ecoregion_intersects.R (includes/wtw solution rasters
  # intersected with the landscape; unprotected % of landscape covered by WTW)
  print("building header...")
  includes_km2 <- intersect_raster_value(custom$protected_grid_path, landscape_sf) / 100
  prz_km2      <- intersect_raster_value(cfg$prioritization_raster$prioritization_wtw, landscape_sf) / 100

  out <- data.frame(
    ecoregion_inland_km2  = landscape_km2,
    protected_inland_pcnt = round(protected_km2 / landscape_km2 * 100, 2),
    wtw_area_inland_km2   = prz_km2,
    wtw_inland_percent    = round(prz_km2 / (landscape_km2 - includes_km2) * 100, 2),
    stringsAsFactors      = FALSE
  )

  # pressures -- % of landscape covered by each pressure raster
  print("building pressures...")
  pressure_map <- c(
    forestry_pcnt       = "pressure_forestry",
    agriculture_pcnt    = "pressure_agriculture",
    transport_high_pcnt = "pressure_transport_high",
    transport_low_pcnt  = "pressure_transport_low",
    energy_pcnt         = "pressure_energy",
    builtup_pcnt        = "pressure_builtup"
  )
  for (col in names(pressure_map)) {
    ha <- intersect_raster_value(cfg$pressures_raster[[pressure_map[[col]]]], landscape_sf)
    out[[col]] <- round(ha / landscape_ha * 100, 2)
  }

  # unprotected intact/modified -- per erap-deer-code's
  # 4_protected_intact_modified.R (subtract the protected portion from the
  # landscape total, then express each as a % of the unprotected total)
  print("building intactness...")
  intact_total_ha   <- intersect_raster_value(cfg$pressures_raster$pressure_intact, landscape_sf)
  modified_total_ha <- intersect_raster_value(cfg$pressures_raster$pressure_modified, landscape_sf)
  intact_pa_ha   <- if (protected_km2 > 0) intersect_raster_value(cfg$pressures_raster$pressure_intact, protected_in_landscape_sf) else 0
  modified_pa_ha <- if (protected_km2 > 0) intersect_raster_value(cfg$pressures_raster$pressure_modified, protected_in_landscape_sf) else 0

  unprotected_intact_ha   <- intact_total_ha - intact_pa_ha
  unprotected_modified_ha <- modified_total_ha - modified_pa_ha
  unprotected_total_ha    <- unprotected_intact_ha + unprotected_modified_ha

  out$unprotected_intact_pcnt   <- round(unprotected_intact_ha   / unprotected_total_ha * 100, 2)
  out$unprotected_modified_pcnt <- round(unprotected_modified_ha / unprotected_total_ha * 100, 2)

  # habitats -- forest is a raster; grassland/wetland/lakes are vector polygons
  print("building habitat...")
  for (hab in c("forest", "grassland", "wetland", "lakes")) {
    if (hab == "forest") {
      hab_path     <- cfg$habitat_raster$habitat_forest
      total_ha     <- intersect_raster_value(hab_path, landscape_sf)
      protected_ha <- if (protected_km2 > 0) intersect_raster_value(hab_path, protected_in_landscape_sf) else 0
      wtw_ha       <- if (has_wtw_vector) intersect_raster_value(hab_path, wtw_in_landscape_sf) else 0
    } else {
      hab_path     <- cfg$habitat_vector[[paste0("habitat_", hab)]]
      total_ha     <- intersect_vector_value(hab_path, custom$landscape_path)
      protected_ha <- if (protected_km2 > 0) intersect_vector_value(hab_path, c(custom$landscape_path, custom$protected_vector_path)) else 0
      wtw_ha       <- if (has_wtw_vector) intersect_vector_value(hab_path, c(custom$landscape_path, custom$wtw_vector_path)) else 0
    }
    out[[paste0("pcnt_ecoregion_", hab, "_cover")]] <- round(total_ha / landscape_ha * 100, 2)
    out[[paste0("pcnt_", hab, "_protected")]]       <- round(if (total_ha > 0) protected_ha / total_ha * 100 else 0, 2)
    out[[paste0("pcnt_", hab, "_wtw")]]             <- round(if (total_ha > 0) wtw_ha       / total_ha * 100 else 0, 2)
  }

  # linear habitats -- rivers/shoreline are vector polylines
  print("building linear habitat...")
  for (hab in c("rivers", "shoreline")) {
    hab_path     <- cfg$habitat_vector[[paste0("habitat_", hab)]]
    total_km     <- intersect_vector_value(hab_path, custom$landscape_path)
    protected_km <- if (protected_km2 > 0) intersect_vector_value(hab_path, c(custom$landscape_path, custom$protected_vector_path)) else 0
    wtw_km       <- if (has_wtw_vector) intersect_vector_value(hab_path, c(custom$landscape_path, custom$wtw_vector_path)) else 0

    out[[paste0(hab, "_km")]]                 <- total_km
    out[[paste0("pcnt_", hab, "_protected")]] <- round(if (total_km > 0) protected_km / total_km * 100 else 0, 2)
    out[[paste0("pcnt_", hab, "_wtw")]]       <- round(if (total_km > 0) wtw_km       / total_km * 100 else 0, 2)
  }

  out
}
