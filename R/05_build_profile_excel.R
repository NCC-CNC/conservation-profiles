source("R/fct_read_feature.R")
source("R/fct_get_landscape_id.R")
source("R/fct_excel_styles.R")
source("R/fct_custom_landscape_geoms.R")
source("R/fct_build_custom_erap_row.R")

erap_header_cols <- c(
  "ecoregion_inland_km2",
  "protected_inland_pcnt",
  "wtw_inland_percent",
  "wtw_area_inland_km2"
)
habitat_area_cols <- c(
  "pcnt_ecoregion_forest_cover",
  "pcnt_forest_protected",
  "pcnt_forest_wtw",
  "pcnt_ecoregion_grassland_cover",
  "pcnt_grassland_protected",
  "pcnt_grassland_wtw",
  "pcnt_ecoregion_wetland_cover",
  "pcnt_wetland_protected",
  "pcnt_wetland_wtw",
  "pcnt_ecoregion_lakes_cover",
  "pcnt_lakes_protected",
  "pcnt_lakes_wtw"
)
habitat_linear_cols <- c(
  "rivers_km",
  "pcnt_rivers_protected",
  "pcnt_rivers_wtw",
  "shoreline_km",
  "pcnt_shoreline_protected",
  "pcnt_shoreline_wtw"
)
pressure_cols <- c(
  "forestry_pcnt",
  "agriculture_pcnt",
  "transport_high_pcnt",
  "transport_low_pcnt",
  "energy_pcnt",
  "builtup_pcnt"
)
intactness_cols <- c(
"unprotected_intact_pcnt", 
"unprotected_modified_pcnt"
)

# Combine multiple ERAP rows into one combined row.
# All percentage columns are recomputed as: sum(feature_area) / sum(denominator_area).
# Returns the single row unchanged for single-ecoregion projects.
combine_erap_rows <- function(rows) {
  if (nrow(rows) == 1) return(rows)

  A <- rows$ecoregion_inland_km2
  W <- sum(A)
  out <- rows[1, , drop = FALSE]

  # concatenate name fields
  out$ECOREGION  <- paste(rows$ECOREGION,  collapse = " / ")
  out$REGION_NAM <- paste(rows$REGION_NAM, collapse = " / ")
  out$REGION_NOM <- paste(rows$REGION_NOM, collapse = " / ")

  # concatenate ecozone fields only when ecoregions span different ecozones
  if (length(unique(rows$ECOZONE)) > 1) {
    out$ECOZONE    <- paste(rows$ECOZONE,    collapse = " / ")
    out$ZONE_NAME  <- paste(rows$ZONE_NAME,  collapse = " / ")
    out$ZONE_NOM   <- paste(rows$ZONE_NOM,   collapse = " / ")
  }

  out$ecoregion_inland_km2 <- W
  out$wtw_area_inland_km2  <- sum(rows$wtw_area_inland_km2)

  # header pcts: sum(feature_km2) / sum(inland_km2) * 100
  protected_km2_total       <- sum(rows$protected_km2)
  out$protected_inland_pcnt <- protected_km2_total / W * 100

  # wtw %: same "% of the *unprotected* portion" method as
  # build_custom_erap_row() (wtw area / (landscape area - already-protected
  # area), not the full landscape area) -- ERAP_ecoregions.gdb has no separate
  # raw "includes" column to recombine here, so protected_km2 (already summed
  # above for protected_inland_pcnt) stands in as that already-protected baseline
  # Update this with ERAPS v2 to pass the Include_km2 for each ecoregion into the ERAP
  # table so we can use it here. Added as issue #1
  out$wtw_inland_percent <- out$wtw_area_inland_km2 / (W - protected_km2_total) * 100

  # pressures: sum(feature_km2) / sum(inland_km2) * 100
  out$forestry_pcnt        <- sum(rows$forestry_km2)       / W * 100
  out$agriculture_pcnt     <- sum(rows$agriculture_km2)    / W * 100
  out$transport_high_pcnt  <- sum(rows$transport_high_km2) / W * 100
  out$transport_low_pcnt   <- sum(rows$transport_low_km2)  / W * 100
  out$energy_pcnt          <- sum(rows$energy_km2)         / W * 100
  out$builtup_pcnt         <- sum(rows$builtup_km2)        / W * 100

  # intactness has no area column; rows values are already %, scale is preserved
  out$unprotected_intact_pcnt   <- sum(A * rows$unprotected_intact_pcnt)   / W
  out$unprotected_modified_pcnt <- sum(A * rows$unprotected_modified_pcnt) / W

  # habitats: cover = sum(hab_km2) / sum(inland_km2) * 100
  #           protected/wtw = sum(protected_hab_km2) / sum(hab_km2) * 100
  for (hab in c("forest", "grassland", "wetland", "lakes")) {
    H <- sum(rows[[paste0(hab, "_km2")]])
    out[[paste0("pcnt_ecoregion_", hab, "_cover")]] <- H / W * 100
    out[[paste0("pcnt_", hab, "_protected")]] <- if (H > 0) sum(rows[[paste0(hab, "_protected_km2")]]) / H * 100 else 0
    out[[paste0("pcnt_", hab, "_wtw")]]       <- if (H > 0) sum(rows[[paste0(hab, "_wtw_km2")]])       / H * 100 else 0
  }

  # linear: sum km; protected/wtw = sum(protected_km) / sum(total_km) * 100
  out$rivers_km    <- sum(rows$rivers_km)
  out$shoreline_km <- sum(rows$shoreline_km)
  R <- out$rivers_km;  S <- out$shoreline_km
  out$pcnt_rivers_protected    <- if (R > 0) sum(rows$rivers_protected_km)    / R * 100 else 0
  out$pcnt_rivers_wtw          <- if (R > 0) sum(rows$rivers_wtw_km)          / R * 100 else 0
  out$pcnt_shoreline_protected <- if (S > 0) sum(rows$shoreline_protected_km) / S * 100 else 0
  out$pcnt_shoreline_wtw       <- if (S > 0) sum(rows$shoreline_wtw_km)       / S * 100 else 0

  out
}

build_profile_tab <- function(project_data, erap_path, identifier_col, landscape_id, species_df, species_summary_df, other_df = NULL, geoms = NULL, cfg = NULL, toml_path = "setup.toml"){

  # cfg should be the pipeline's already-prepared config (input$data from
  # setup()) so custom_landscape$landscape_path reflects reproject_project_path()'s
  # on-the-fly reprojection -- a fresh parseTOML() here would silently fall
  # back to the original (possibly wrong-CRS) path.
  if (is.null(cfg)) cfg <- RcppTOML::parseTOML(toml_path)
  custom <- cfg$custom_landscape

  # load erap table — support single or multiple landscape IDs, or build one
  # on the fly for a user-supplied custom landscape
  print("loading landscape data...")
  erap_row <- if (!is.null(custom$landscape_path) && nzchar(custom$landscape_path)) {
    build_custom_erap_row(cfg, geoms)
  } else {
    read_feature(erap_path) |>
      sf::st_drop_geometry() |>
      dplyr::filter(.data[[identifier_col]] %in% landscape_id) |>
      combine_erap_rows()
  }

  # pull header columns
  print("building header table...")
  header_df <-
    data.frame(
      Project_name = gsub("_", " ", project_name),
      Project_area_ha = project_data$Project_value[project_data$Dataset == "Project"],
      Project_wtw_ha = project_data$Project_value[project_data$Dataset == "prioritization_wtw"]) |>
    cbind(erap_row[erap_header_cols]) |>
    dplyr::mutate(
      `project_%_of_ecoregion` = round(Project_area_ha / (ecoregion_inland_km2 * 100) * 100, 2),
      `%_of_project_in_WTW`    = round(Project_wtw_ha / Project_area_ha * 100, 2)
    )

  # ECOREGION/REGION_NAM/REGION_NOM/ECOZONE/ZONE_NAME/ZONE_NOM always reflect
  # the real ecoregion(s)/ecozone(s) the *project* itself overlaps (looked up
  # from erap_path's attribute table), regardless of whether a custom
  # landscape is being compared against -- concatenated with " / " when the
  # project spans more than one (matching combine_erap_rows()' convention).
  project_sf <- read_feature(cfg$project$project_path) |> sf::st_union() |> sf::st_as_sf()
  project_overlap <- get_overlapping_ecoregions(project_sf, erap_path)
  for (col in c("ECOREGION", "REGION_NAM", "REGION_NOM", "ECOZONE", "ZONE_NAME", "ZONE_NOM")) {
    header_df[[col]] <- paste(unique(project_overlap[[col]]), collapse = " / ")
  }

  # landscape_name is the comparison target's display name: the custom
  # landscape's name if one was provided, otherwise erap_row$REGION_NAM --
  # i.e. whichever ecoregion(s) were actually used for the comparison
  # (get_landscape_id()'s dominant one, or force_ecoregion's explicit list).
  # This can differ from the project's real overlap above -- e.g.
  # force_ecoregion lets a user compare against ecoregions the project
  # doesn't fully intersect.
  header_df$landscape_name <- if (!is.null(custom$landscape_path) && nzchar(custom$landscape_path))
    custom$landscape_name else erap_row$REGION_NAM

  # pull habitat cols
  print("building habitat table...")
  habitat_area_df <- erap_row[habitat_area_cols] |>
    tidyr::pivot_longer(everything()) |>
    dplyr::mutate(
      habitat = stringr::str_match(name, "_([^_]+)_[^_]+$")[, 2],
      metric  = sub(".*_", "", name)) |>
    dplyr::select(-name) |>
    tidyr::pivot_wider(names_from = metric, values_from = value) |>
    dplyr::rename(
      Habitat = habitat,
      '% cover in ecoregion' = cover,
      '% of habitat protected' = protected,
      '% of habitat overlapping WTW' = wtw) |>
    dplyr::left_join(
      project_data |>
        dplyr::filter(grepl("^habitat_", Dataset), !grepl("rivers|shoreline", Dataset)) |>
          dplyr::mutate(Habitat = sub("habitat_", "", Dataset)) |>
        dplyr::select(Habitat, 'Project total (ha)' = Project_value),
      by = "Habitat"
    )
    
  habitat_linear_df <- erap_row[habitat_linear_cols] |>
    tidyr::pivot_longer(everything()) |>
    dplyr::mutate(
      habitat = stringr::str_extract(name, "rivers|shoreline"),
      metric  = sub(".*_", "", name)) |>
    dplyr::select(-name) |>
    tidyr::pivot_wider(names_from = metric, values_from = value) |>
    dplyr::rename(
      Habitat = habitat,
      'Total in ecoregion (km)' = km,
      '% of habitat protected' = protected, 
      '% of habitat overlapping WTW' = wtw) |>
    dplyr::left_join(
      project_data |>
        dplyr::filter(grepl("^habitat_", Dataset), grepl("rivers|shoreline", Dataset)) |>
          dplyr::mutate(Habitat = sub("habitat_", "", Dataset)) |>
          dplyr::select(Habitat, 'Project total (km)' = Project_value),
        by = "Habitat"
      )
    
  # pull pressures
  print("building pressures table...")
  pressures_df <- erap_row[pressure_cols] |>
    tidyr::pivot_longer(everything()) |>
    dplyr::left_join(
      project_data |>
      dplyr::filter(grepl("^pressure_", Dataset)) |>
      dplyr::mutate(name = paste0(sub("pressure_", "", Dataset), "_pcnt")) |>
      dplyr::select(name, 'Project total (ha)' = Project_value) |>
      dplyr::mutate(`% of project` = `Project total (ha)` / header_df$Project_area_ha *100),
        by = "name"
      ) |>
    dplyr::mutate(name = dplyr::replace_values(
      name,
      "forestry_pcnt" ~ "Forestry footprint",
      "agriculture_pcnt" ~ "Agriculture footprint",
      "transport_high_pcnt" ~ "Transport footprint - higher intensity",
      "transport_low_pcnt" ~ "Transport footprint - lower intensity",
      "energy_pcnt" ~ "Energy and mining footprint",
      "builtup_pcnt" ~ "Urban and built up footprint"
    )) |>
    dplyr::rename(
    "Pressure" = name,
    '% of ecoregion' = value
  )
  
  # pull intactness
  print("building intactness table...")
  intactness_df <- erap_row[intactness_cols] |>
    dplyr::rename(
      "intact" = unprotected_intact_pcnt,
      "modified" = unprotected_modified_pcnt) |>
    tidyr::pivot_longer(everything()) |>
    dplyr::left_join(
      project_data |>
      dplyr::filter(grepl("^pressure_", Dataset)) |>
      dplyr::mutate(name = sub("pressure_", "", Dataset)) |>
      dplyr::select(name, 'Project total (ha)' = Project_value) |>
      dplyr::filter(name %in% c("intact", "modified")) |>
      dplyr::mutate("% of project" = round(`Project total (ha)` / sum(`Project total (ha)`, na.rm = TRUE) *100, 1)),
        by = "name"
      ) |>
    dplyr::mutate(name = dplyr::replace_values(
      name,
      "intact" ~ "Intact",
      "modified" ~ "Modified")) |>
    dplyr::rename(
      "Condition" = name,
      "% of ecoregion" = value)
    
  print("saving xlsx...")
  # combine into formatted excel table and save
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Header")
  openxlsx::writeData(wb, "Header", header_df)
  apply_ncc_table(wb, "Header", header_df)

  openxlsx::addWorksheet(wb, "Habitat")
  openxlsx::writeData(wb, "Habitat", habitat_area_df)
  apply_ncc_table(wb, "Habitat", habitat_area_df)
  openxlsx::writeData(wb, "Habitat", habitat_linear_df, startRow = nrow(habitat_area_df) + 4)
  apply_ncc_table(wb, "Habitat", habitat_linear_df, start_row = nrow(habitat_area_df) + 4)
  
  openxlsx::addWorksheet(wb, "Pressures")
  openxlsx::writeData(wb, "Pressures", intactness_df)
  apply_ncc_table(wb, "Pressures", intactness_df)
  openxlsx::writeData(wb, "Pressures", pressures_df, startRow = nrow(intactness_df) + 4)
  apply_ncc_table(wb, "Pressures", pressures_df, start_row = nrow(intactness_df) + 4)

  openxlsx::addWorksheet(wb, "Species Summary")
  openxlsx::writeData(wb, "Species Summary", species_summary_df)
  apply_ncc_table(wb, "Species Summary", species_summary_df)

  openxlsx::addWorksheet(wb, "Species")
  openxlsx::writeData(wb, "Species", species_df)
  apply_ncc_table(wb, "Species", species_df)

  if (!is.null(other_df)) {
    other_display_df <- data.frame(
      Layer = tools::toTitleCase(gsub("_", " ", other_df$Dataset)),
      `Project value` = other_df$Project_value,
      Unit = other_df$Unit,
      check.names = FALSE
    )
    ha_rows <- other_df$Unit == "ha"
    other_display_df$`% of project`[ha_rows] <- round(
      other_df$Project_value[ha_rows] / header_df$Project_area_ha * 100, 1
    )
    openxlsx::addWorksheet(wb, "Other")
    openxlsx::writeData(wb, "Other", other_display_df)
    apply_ncc_table(wb, "Other", other_display_df)
  }

  source_data_df <- do.call(rbind, lapply(names(cfg), function(section) {
    keys <- setdiff(names(cfg[[section]]), "project_dir")
    data.frame(Variable = keys, Path = unlist(cfg[[section]][keys]), stringsAsFactors = FALSE, row.names = NULL)
  }))
  openxlsx::addWorksheet(wb, "source_data")
  openxlsx::writeData(wb, "source_data", source_data_df)
  apply_ncc_table(wb, "source_data", source_data_df)

  xlsx_path <- file.path(input$data$project$project_dir, paste0(project_name, "_conservation_profile.xlsx"))
  tryCatch(
    openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE),
    error = function(e) stop("Could not save Excel file (is it open?): ", xlsx_path, "\n", conditionMessage(e))
  )

  return(
    list(
      header = header_df,
      habitat_area = habitat_area_df,
      habitat_linear = habitat_linear_df,
      intactness = intactness_df,
      pressures = pressures_df,
      species_summary = species_summary_df,
      species = species_df,
      other = other_df
    )
  )
}