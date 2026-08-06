#' This codebase is intended to live in one shared, git-synced location.
#' Each project gets its own folder containing just a `run_template.R` copy
#' (renamed `run.R`) and a `setup.toml` -- see run_template.R at the repo root.
#'
#' Installs any missing R packages
#' Reads in `setup.toml` (or the path passed in) and sets paths.
#'
#' @return A list with one element. "data" contains the parsed contents of
#' `setup.toml`.
#'
#' -----------------------------------------------------------------------------

source(file.path(CODE_DIR, "R/fct_get_landscape_id.R"))
source(file.path(CODE_DIR, "R/fct_ecozone_lookup.R"))
source(file.path(CODE_DIR, "R/fct_reproject_project_path.R"))

setup <- function(toml_path = "setup.toml") {
  required_pkgs <- c(
    "dplyr",
    "tidyr",
    "RcppTOML",
    "readr",
    "readxl",
    "sf",
    "terra",
    "exactextractr",
    "reticulate",
    "stringr",
    "openxlsx",
    "gridExtra",
    "png",
    "pagedown"
  )

  # Install missing packages
  for (pkg in required_pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message(sprintf("Installing %s...", pkg))
      install.packages(pkg, repos = "https://cloud.r-project.org")
    }
  }

  terra::gdalCache(size = 8000) # Set GDAL cache size to 8GB -- after install, terra may not exist yet on a fresh system

  # Read-in toml and return configs
  cfg <- RcppTOML::parseTOML(toml_path)

  # [custom_landscape] holds the two user-edited fields (landscape_name/
  # landscape_path); [custom_landscape_data] holds the pre-configured backend
  # paths. Merged here so the rest of the pipeline only ever deals with a
  # single cfg$custom_landscape list.
  cfg$custom_landscape <- c(cfg$custom_landscape, cfg$custom_landscape_data)
  cfg$custom_landscape_data <- NULL

  cfg <- reproject_project_path(cfg)

  return(list(data = cfg))
}
