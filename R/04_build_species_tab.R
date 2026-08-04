extract_raster_stack <- function(r_stack, boundary_sf) {

  vals <- exactextractr::exact_extract(
    x = r_stack,
    y = boundary_sf,
    fun = "sum",
    coverage_area = TRUE
  )
  names(vals) <- sub("^sum\\.", "", names(vals))
  vals_pivot <- tidyr::pivot_longer(
    data = round(vals / 10000, 4), # m2 to ha
    cols = colnames(vals),
    names_to = "File",
    values_to = "Project_ha"
  )
  return(vals_pivot)
}

# Pulls the multi-band species raster stack from species_dir. Built once by
# build_species_tab() and passed to both species_intersect() and
# build_landscape_species_tab() so the (1000+ file) stack only loads once per run.
build_species_stack <- function(species_dir) {
  r_paths <- list.files(species_dir, recursive = TRUE, full.names = TRUE, pattern = ".tiff?$")
  r_stack <- terra::rast(r_paths)
  names(r_stack) <- basename(terra::sources(r_stack))
  r_stack
}

# Extracts total species-range area (km2) within boundary_sf from a species
# raster stack, mirroring erap-deer-code's ecoregion/PA species extraction:
# plain exact_extract 'sum' (no coverage_area weighting) -- these rasters
# already encode km2-equivalent area per cell, unlike the ha/coverage-weighted
# convention extract_raster_stack() uses for the project side.
extract_species_km2 <- function(r_stack, boundary_sf, value_col) {
  vals <- exactextractr::exact_extract(r_stack, boundary_sf, fun = "sum")
  names(vals) <- sub("^sum\\.", "", names(vals))
  df <- tidyr::pivot_longer(vals, cols = colnames(vals), names_to = "File", values_to = value_col)
  df[[value_col]][grepl("ECCC", df$File)] <- df[[value_col]][grepl("ECCC", df$File)] / 100
  df
}

# Loads Canada-wide species metadata from an Excel workbook (one sheet per
# source), mirroring the metadata-prep block in erap-deer-code's
# 5c_species_extractions.R. Needed only for custom landscapes -- the
# ecoregion-CSV path already has these Canada_ columns baked in.
load_species_meta <- function(species_metadata_path) {
  sheets <- readxl::excel_sheets(species_metadata_path)
  meta <- do.call(rbind, lapply(sheets, function(sheet) {
    readxl::read_excel(species_metadata_path, sheet) |>
      dplyr::select(Source, File, Theme, Sci_Name, Common_Name, Threat, Total_Km2, Protected_Km2, Pct_Protected, Goal)
  }))

  names(meta)[names(meta) == "Total_Km2"]     <- "Canada_Total_km2"
  names(meta)[names(meta) == "Protected_Km2"] <- "Canada_Protected_km2"
  names(meta)[names(meta) == "Pct_Protected"] <- "Canada_Pct_Protected"
  names(meta)[names(meta) == "Goal"]          <- "Canada_Pct_Goal"

  meta$Canada_Pct_Goal           <- meta$Canada_Pct_Goal * 100
  meta$Canada_km2_Goal           <- meta$Canada_Total_km2 * (meta$Canada_Pct_Goal / 100)
  meta$Canada_Protection_Gap_km2 <- pmax(meta$Canada_km2_Goal - meta$Canada_Protected_km2, 0)

  meta
}

# Custom-landscape equivalent of one iteration of erap-deer-code's
# 5c_species_extractions.R ecoregion loop: extracts total + protected species
# range within the landscape, joins Canada-wide metadata, and computes the
# landscape protection goal/gap -- using Landscape_*/Pct_Canada_range_in_landscape
# column names so it slots into build_species_tab()/summarise_species_tab()
# identically to the ecoregion-CSV path. Takes a pre-built r_stack (see
# build_species_stack()) so build_species_tab() only loads the species raster
# stack once per pipeline run, not once per boundary.
build_landscape_species_tab <- function(r_stack, custom_landscape, geoms) {

  print("building landscape species table")

  df_total <- extract_species_km2(r_stack, geoms$landscape_sf, "Landscape_Total_km2")

  df_protected <- if (nrow(geoms$protected_in_landscape_sf) > 0) {
    extract_species_km2(r_stack, geoms$protected_in_landscape_sf, "Landscape_Protected_km2")
  } else {
    dplyr::mutate(df_total, Landscape_Protected_km2 = 0) |> dplyr::select(File, Landscape_Protected_km2)
  }

  df <- dplyr::left_join(df_total, df_protected, by = "File") |>
    dplyr::filter(Landscape_Total_km2 > 0) |>
    tidyr::replace_na(list(Landscape_Protected_km2 = 0))

  species_meta <- load_species_meta(custom_landscape$species_metadata_path)

  dplyr::inner_join(species_meta, df, by = "File") |>
    dplyr::mutate(
      Landscape_Goal_km2            = Canada_Pct_Goal / 100 * Landscape_Total_km2,
      Landscape_Protection_Gap_km2  = pmax(Landscape_Goal_km2 - Landscape_Protected_km2, 0),
      Pct_Canada_range_in_landscape = pmin(Landscape_Total_km2 / Canada_Total_km2 * 100, 100),
      Landscape                     = custom_landscape$landscape_name
    )
}

species_intersect <- function(r_stack, project_path) {

  # currently uses prepped 1km grids but should eventually switch to extracting ECCC from .gdb

  # load project — dissolve to single feature so multi-polygon boundaries don't duplicate extraction rows
  project_sf <- read_feature(project_path) |>
    sf::st_union() |>
    sf::st_as_sf()

  # Note that these extractions are slow and require a lot of memory
  # We don't need to run the extract on all species, only the species intersecting
  # the ecoregion. We could do some pre-calculations (e.g. listing ecoregions that each
  # species intersects) that would allow us to filter down the number of extracts.
  # For now I'm just running the extract on all species.
  sp_df <- extract_raster_stack(r_stack, project_sf)

  # filter for species that intersect project
  sp_df <- sp_df[sp_df$Project_ha > 0,]

  # Note ECCC values are ha of range in the 1km cell. Need to divide by 100
  sp_df$Project_ha[grepl("ECCC", sp_df$File)] <- sp_df$Project_ha[grepl("ECCC", sp_df$File)] / 100

  # add source theme
  sp_df$Source <-
    sapply(sub("T_NAT_", "", sp_df$File), function(x){
      y <- strsplit(x, "_")
      return(paste0(y[[1]][1], "_", y[[1]][2]))
    })

  return(sp_df)
}

build_species_tab <- function(species_dir, project_path, landscape_species_path = NULL, custom_landscape = NULL, geoms = NULL){

  # built once and shared below -- loading the (1000+ file) species stack
  # twice per run would double an already-slow step
  r_stack <- build_species_stack(species_dir)

  # get species extractions for project
  species_df <- species_intersect(r_stack, project_path)

  if (!is.null(custom_landscape)) {

    landscape_df <- build_landscape_species_tab(r_stack, custom_landscape, geoms)

  } else {

    # read one or more ecoregion species CSVs
    landscape_df <- do.call(rbind, lapply(landscape_species_path, read.csv)) |>
      dplyr::rename(
        Landscape_Total_km2           = Ecoregion_Total_km2,
        Landscape_Goal_km2            = Ecoregion_Goal_km2,
        Landscape_Protected_km2       = Ecoregion_Protected_km2,
        Landscape_Protection_Gap_km2  = Ecoregion_Protection_Gap_km2,
        Pct_Canada_range_in_landscape = Pct_Canada_range_in_ecoregion
      )

    # combine duplicate species (same File across multiple ecoregions)
    if (length(landscape_species_path) > 1) {
      landscape_df <- landscape_df |>
        dplyr::group_by(File) |>
        dplyr::summarise(
          Ecozone                   = paste(unique(Ecozone),   collapse = " / "),
          Ecoregion                 = paste(unique(Ecoregion), collapse = " / "),
          Source                    = dplyr::first(Source),
          Theme                     = dplyr::first(Theme),
          Sci_Name                  = dplyr::first(Sci_Name),
          Common_Name               = dplyr::first(Common_Name),
          Threat                    = dplyr::first(Threat),
          Canada_Total_km2          = dplyr::first(Canada_Total_km2),
          Canada_Protected_km2      = dplyr::first(Canada_Protected_km2),
          Canada_Pct_Goal           = dplyr::first(Canada_Pct_Goal),
          Canada_km2_Goal           = dplyr::first(Canada_km2_Goal),
          Canada_Protection_Gap_km2 = dplyr::first(Canada_Protection_Gap_km2),
          Landscape_Total_km2       = sum(Landscape_Total_km2),
          Landscape_Protected_km2   = sum(Landscape_Protected_km2),
          .groups = "drop"
        ) |>
        dplyr::mutate(
          Landscape_Goal_km2            = Landscape_Total_km2 * (Canada_Pct_Goal / 100),
          Landscape_Protection_Gap_km2  = pmax(Landscape_Goal_km2 - Landscape_Protected_km2, 0),
          Pct_Canada_range_in_landscape = Landscape_Total_km2 / Canada_Total_km2 * 100
        )
    }
  }

  # join project species data — explicit key prevents many-to-many match on shared columns (e.g. Source)
  landscape_df <- dplyr::left_join(
    landscape_df,
    dplyr::select(species_df, File, Project_ha),
    by = "File"
  ) |>
    tidyr::replace_na(list(Project_ha = 0))

  return(landscape_df)
}

summarise_species_tab <- function(species_tab){

  summary_df <-
    species_tab |>
      dplyr::group_by(Source) |>
      dplyr::summarise(
        Landscape_count = dplyr::n(),
        Project_count = sum(Project_ha > 0, na.rm = TRUE),
        National_or_landscape_protection_shortfall = sum(Canada_Protection_Gap_km2 > 0 | Landscape_Protection_Gap_km2 > 0),
        Project_reduces_shortfall = sum((Canada_Protection_Gap_km2 > 0 | Landscape_Protection_Gap_km2 > 0) & Project_ha > 0))

  return(summary_df)
}
