# Instructions for running this pipeline found here: https://github.com/NCC-CNC/conservation-profiles

# Start timer
start_time <- Sys.time()

# CODE_DIR is set by run.R when this codebase is shared across projects (see
# run_template.R); every source()/file path below is built from it explicitly
# rather than relying on the working directory. Falls back to "." (the
# current directory) for a direct, local run.
if (!exists("CODE_DIR")) CODE_DIR <- "."

# 01 Set up
source(file.path(CODE_DIR, "R/01_setup.R"))
source(file.path(CODE_DIR, "R/fct_landscape_setup.R"))
print("01 Setup ...")
# toml_path is set by run.R when this codebase is shared across projects
# (see run_template.R); falls back to a local setup.toml otherwise.
if (!exists("toml_path")) toml_path <- "setup.toml"
input <- setup(toml_path)
project_name <- gsub(" ", "_", input$data$project$project_name)
project_path <- input$data$project$project_path
erap_path <- input$data$paths$erap_path

# Landscape setup
# Choose the reference landscape as one of:
#   Default:           Ecoregion that the majority of the project falls in
#   Force ecoregion(s):User sets force_ecoregion in setup.toml's [custom_landscape]
#                      section, e.g. force_ecoregion = [69, 71] to combine several
#                      ecoregions. If set, takes priority over default.
#   Custom landscape:  Any user provided landscape polygon with a path provided in
#                      setup.toml's [custom_landscape] section. If provided, takes priority
#                      over other options.
force_ecoregion <- input$data$custom_landscape$force_ecoregion
if (length(force_ecoregion) == 0) force_ecoregion <- NULL
landscape <- landscape_setup(input, project_path, erap_path, force_ecoregion = force_ecoregion)
custom_landscape <- landscape$custom_landscape
is_custom         <- landscape$is_custom
geoms             <- landscape$geoms
ecoregion         <- landscape$ecoregion
ecozone           <- landscape$ecozone

# 02 vector extractions
source(file.path(CODE_DIR, "R/02_extract_vector_data.R"))
print("02 Vector ...")
vector_names <- c("Project", names(input$data$habitat_vector)) # add project to get project area
vector_paths <- c(project_path, as.vector(unlist(input$data$habitat_vector)))
extracted_df <- vector_intersect(vector_names, vector_paths, project_path)

# 03 raster extractions
source(file.path(CODE_DIR, "R/03_extract_raster_data.R"))
print("03 Raster ...")
raster_data <- c(input$data$habitat_raster, input$data$pressures_raster, input$data$prioritization_raster)
raster_names <- names(raster_data)
raster_paths <- as.vector(unlist(raster_data))
extracted_df <- rbind(
  extracted_df, 
  raster_intersect(raster_names, raster_paths, project_path)
)

# other project layer extractions
print("Other layers ...")
# peatlands
other_vector_df <- vector_intersect(names(input$data$other_vector), as.vector(unlist(input$data$other_vector)), project_path)
other_vector_df$Unit <- "ha"
#carbon
other_raster_df <- raster_cell_sum_intersect(names(input$data$other_raster), as.vector(unlist(input$data$other_raster)), project_path)
other_raster_df$Unit <- "tonnes"
other_df <- rbind(other_vector_df, other_raster_df)

# 04 species extractions using 1km grid data
source(file.path(CODE_DIR, "R/04_build_species_tab.R"))
print("04 Species ...")
species_dir <- input$data$paths$species_dir
species_df <- if (is_custom) {
  build_species_tab(species_dir, project_path, custom_landscape = custom_landscape, geoms = geoms)
} else {
  erap_species_path <- file.path(input$data$paths$erap_species_dir, paste0("species_assessment_ecozone_", ecozone, "_ecoregion_", ecoregion, ".csv"))
  build_species_tab(species_dir, project_path, landscape_species_path = erap_species_path)
}
species_summary_df <- summarise_species_tab(species_df)

# 05 build conservation profile table
source(file.path(CODE_DIR, "R/05_build_profile_excel.R"))
print("05 Excel ...")
cp_tabs <- build_profile_tab(extracted_df, erap_path, "ECOREGION", ecoregion, species_df, species_summary_df, other_df = other_df, geoms = geoms, cfg = input$data)

# 06 build conservation profile pdf
source(file.path(CODE_DIR, "R/06_build_profile_html.R"))
print("06 PDF...")
build_profile_html_pdf(
  cp_tabs,
  file.path(input$data$project$project_dir, paste0(project_name, "_conservation_profile.pdf")),
  prototype = TRUE
)


end_time <- Sys.time()
print(end_time - start_time)
