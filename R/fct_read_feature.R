read_feature <- function(feature_path, bbox = NULL){

  # spatial pre-filter (GDAL-level, via wkt_filter) -- lets callers avoid
  # reading national-scale layers in full when only a small AOI is needed
  wkt_filter <- if (!is.null(bbox)) sf::st_as_text(sf::st_as_sfc(bbox)) else character(0)

  # shp
  if(endsWith(feature_path, ".shp")){
    return(sf::st_read(feature_path, quiet = TRUE, wkt_filter = wkt_filter))
  # gdb
  } else if(grepl("\\.gdb", feature_path)){
    if(!grepl("\\.gdb/", feature_path))
      stop("GDB path must include a layer name (e.g. 'path/to/file.gdb/LayerName'). Got: ", feature_path)
    split_str <- strsplit(feature_path, ".gdb/")
    return(sf::st_read(paste0(split_str[[1]][1], ".gdb"), split_str[[1]][2], quiet = TRUE, wkt_filter = wkt_filter))
  # csv
  } else if(endsWith(feature_path, ".csv")){
    return(read.csv(feature_path))
  } else{
    return(feature_path)
  }

  # gpkg
  # needs to be added
}
