# Sum forest area in project

library(sf)
library(terra)
library(exactextractr)
library(tidyr)
library(dplyr)
library(readr)

# Set up - DW
CONSP_DATA_MARC <- "C:/Data/PRZ/Conservation_Profiles_Data"
PROJECT_ROOT <- "C:/Data/PRZ/CONSP"
PROJECT_FOLDER <- "TEST"
PROJECT_DIR <- file.path(PROJECT_ROOT,PROJECT_FOLDER)
setwd(PROJECT_DIR)

# create output folder
if(!dir.exists("habitat")){
  dir.create("habitat")
}

# Load project
project_sf <- st_read(file.path("aoi/test_project.shp")) %>%
  summarise(geometry = st_union(.)) %>%
  st_cast("POLYGON")

# Load forests
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Forest/Forest_LC_30m_2022.tif
forests <- rast(file.path(CONSP_DATA_MARC, "habitat_metrics_Jul24_2024/Forest_LC_30m_2022.tif"))

# calculate conversion factor to km2
km2_conversion <- prod(res(forests)/1000)

# Run processing
tib <- tibble(forest_project_km2 = NA)

# extract values for project
tib$forest_project_km2 <- exactextractr::exact_extract(forests, st_union(project_sf), 'sum') * km2_conversion

# save results table
write_csv(tib, "habitat/forests_sums.csv")
