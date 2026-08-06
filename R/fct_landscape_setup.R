source(file.path(CODE_DIR, "R/fct_get_landscape_id.R"))
source(file.path(CODE_DIR, "R/fct_ecozone_lookup.R"))
source(file.path(CODE_DIR, "R/fct_custom_landscape_geoms.R"))

# Resolves what "landscape" the ERAP row/species table get compared against:
# a custom user-supplied landscape (setup.toml's [custom_landscape] section)
# takes priority when set; otherwise the project's own ecoregion(s) are looked
# up (or, if force_ecoregion is supplied, used directly instead of looking
# them up -- e.g. force_ecoregion = c(69, 71) to treat several ecoregions as
# one combined landscape via combine_erap_rows()). force_ecoregion is ignored
# when a custom landscape is set.
landscape_setup <- function(input, project_path, erap_path, force_ecoregion = NULL) {
  custom_landscape <- input$data$custom_landscape
  is_custom <- !is.null(custom_landscape$landscape_path) && nzchar(custom_landscape$landscape_path)

  if (is_custom) {
    geoms <- get_custom_landscape_geoms(custom_landscape)
    ecoregion <- NA
    ecozone <- NA
  } else {
    geoms <- NULL
    ecoregion <- if (!is.null(force_ecoregion)) force_ecoregion else get_landscape_id(project_path, erap_path, "ECOREGION")
    ecozone <- ecozone_lookup(ecoregion)
  }

  list(
    custom_landscape = custom_landscape,
    is_custom        = is_custom,
    geoms            = geoms,
    ecoregion        = ecoregion,
    ecozone          = ecozone
  )
}
