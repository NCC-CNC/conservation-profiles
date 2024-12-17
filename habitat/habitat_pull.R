#
# Author: Dan Wismer
#
# Date: December 17th, 2024
#
# Description: Pulls habitat data to polygons.
#              Uses R to extract raster data, and ArcPy to intersect vector data.
#
# Inputs:  1. AOI polygon shp
#          2. Output location/name for AOI_Habitat polygon shp
#
# Outputs: 1. polygon with habitat areas and lengths 
#
# Tested on R Version: 4.4.1
#
#===============================================================================

# Start timer
start_time <- Sys.time()

library(exactextractr)
library(sf)
library(terra)
library(units)
library(reticulate)

# CHANGE THESE PATHS FOR NEW AOIs
aoi_path <- "C:/Data/PRZ/CONSP/HASTINGS/aoi/Hastings.shp"
aoi_habitat <- "C:/Data/PRZ/CONSP/HASTINGS/Hastings_Habitat.shp"

# Get projection
canada_albers_wgs_1984 <- readLines("habitat/Canada_Albers_WGS_1984.txt")

# Read-in aoi, project to Canada_Albers_WGS_1984 
aoi <- read_sf(aoi_path) %>%
  st_transform(crs = st_crs(canada_albers_wgs_1984))
aoi$HAB_ID <- seq.int(nrow(aoi)) # add unique habitat id
aoi$AREA_HA <- round(drop_units(set_units(st_area(aoi), value = ha)), 2) # Add Area Ha 
  
# Get data
habitat_configs <- read.csv("habitat/habitat_configs.csv")
forest_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Forest"]
# Pass these variables to python
wet_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Wetland"]
grass_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Grassland"]
lake_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Lakes"]
river_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Rivers"]
shore_path <- habitat_configs$PATH[habitat_configs$HABITAT == "Shoreline"]

# Pull forest
aoi$FOREST <- exact_extract( rast(forest_path), aoi, 'sum')
aoi$FOREST <- round(((aoi$FOREST  * 900) / 10000), 2) # convert to ha and round
write_sf(aoi, aoi_habitat) # Write sf to disk as shp

# Pull vector habitat in ArcPy
source_python("habitat/fct_vector_pull.py")
py_run_string('
import arcpy
arcpy.env.overwriteOutput = True

# strcture data 
habitat_data = [r.wet_path, r.grass_path, r.lake_path, r.river_path, r.shore_path]
habitat_cols = ["WETLAND", "GRASSLAND", "LAKES", "RIVERS", "SHORELINE"]

# pull vector habitat
for hab_data, hab_col in zip(habitat_data, habitat_cols):
  
  print("Habitat: {}".format(hab_col))
  vector_pull(
    vector = hab_data, 
    boundary = r.aoi_habitat, 
    col_name = hab_col, 
    uid_col = "HAB_ID"
  )
')

# End timer
end_time <- Sys.time()
end_time - start_time
