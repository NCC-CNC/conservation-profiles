arcgis_cfg <- RcppTOML::parseTOML(file.path(CODE_DIR, "arcgis_config.toml"))
reticulate::use_python(arcgis_cfg$python_path)
reticulate::source_python(file.path(CODE_DIR, "R/fct_intersect_vector_value.py"))
set_output_projection(input$data$habitat_raster$habitat_forest)

vector_intersect <- function(vector_names, vector_paths, project_path){
  
  results <- list()
  for (i in 1:length(vector_paths)) {
    
    cat(sprintf("Processing %s - %s\n", vector_names[i], vector_paths[i]))

    project_value <- intersect_vector_value(vector_paths[i], project_path)
  
    results[[i]] <- data.frame(
      Dataset = vector_names[i],
      Path = vector_paths[i],
      Project_value = project_value,
      check.names = FALSE
    )
  }
  
  # Stack the per-row data.frames in `results` into a single data.frame
  return(do.call(rbind, results))
}