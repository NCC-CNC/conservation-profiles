read_raster <- function(raster_path){

  # tif / tiff
  if(endsWith(raster_path, ".tif") || endsWith(raster_path, ".tiff")){
    return(terra::rast(raster_path))
  # gdb — GDAL OpenFileGDB driver; path must include layer name (path/to/file.gdb/RasterName)
  } else if(grepl("\\.gdb", raster_path)){
    if(!grepl("\\.gdb/", raster_path))
      stop("GDB path must include a raster layer name (e.g. 'path/to/file.gdb/RasterName'). Got: ", raster_path)
    split_str <- strsplit(raster_path, "\\.gdb/")
    gdb_path   <- paste0(split_str[[1]][1], ".gdb")
    layer_name <- split_str[[1]][2]
    return(terra::rast(paste0("OpenFileGDB:", gdb_path, ":", layer_name)))
  } else {
    stop("Unsupported raster format. Provide a .tif/.tiff path or a .gdb/LayerName path. Got: ", raster_path)
  }

}
