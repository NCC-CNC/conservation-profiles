# Re create the ERAP table for an individual project

rm(list = ls(all.names = TRUE))
gc()

library(dplyr)
library(terra)
library(sf)
library(exactextractr)
library(readr)

# set ecoregion
eco <- 96

# open ERAP table
erap <- st_read("C:/Users/marc.edwards/Documents/PROJECTS/Canada_wide_ecoregion_assessments/output/ERAP_ecoregions.gdb", "ERAP_ecoregions") %>%
  st_drop_geometry()

# subset to ecoregion
erap <- erap[erap$ECOREGION == eco,]

# Load project
project_sf <- st_read("test_project.shp") %>%
  summarise(geometry = st_union(.)) %>%
  st_cast("POLYGON")

# Open WTW solution
# Open solution
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/Canada_wtw_2024.tif
s1 <- rast("C:/Users/marc.edwards/Documents/PROJECTS/Canada_wide_ecoregion_assessments/processing/prioritizr/ecozones/Canada_wtw_2024.tif")


tib <- tibble(
  project_area_km = NA,
  project_wtw_area_km2 = NA,
  project_wtw_percent = NA)

# calculate total project area
tib$project_area_km <- sum(as.numeric(st_area(project_sf)) / 1000000)

# calculate project prioritizr area
tib$project_wtw_area_km2 <- sum(exact_extract(s1, project_sf, 'sum'))

# calculate % of project that's a priority
tib$project_wtw_percent <- tib$project_wtw_area_km2 / tib$project_area_km * 100


### HABITAT ###
# Forest
forest_df <- read_csv("habitat/forests_sums.csv")
tib$Project_Forest_km2 <- forest_df$forest_project_km2
tib$Project_Grassland_km2 <- st_read("habitat/habitat.gdb/", "grassland_project_table") %>% pull(grassland_km2_project) %>% ifelse(length(.)==0, 0, .)
tib$Project_Wetland_km2 <- st_read("habitat/habitat.gdb/", "wetland_project_table") %>% pull(wetland_km2_project) %>% ifelse(length(.)==0, 0, .)
tib$Project_Lakes_km2 <- st_read("habitat/habitat.gdb/", "lakes_project_table") %>% pull(lakes_km2_project) %>% ifelse(length(.)==0, 0, .)
tib$Project_Rivers_km <- st_read("habitat/habitat.gdb/", "rivers_project_table") %>% pull(rivers_km_project) %>% ifelse(length(.)==0, 0, .)
tib$Project_Shoreline_km <- st_read("habitat/habitat.gdb/", "shoreline_project_table") %>% pull(shoreline_km_project) %>% ifelse(length(.)==0, 0, .)

### THREATS ###
# Load threat data - Not currently reporting on Human Intrusion or Pollution
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_fr2022_r90_merged_prj_30.tif
forestry <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_fr2022_r90_merged_prj_30.tif")
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_tr2022_r90_merged_prj_30.tif
transport <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_tr2022_r90_merged_prj_30.tif")
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_en2022_r90_merged_prj_30.tif
energy <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_en2022_r90_merged_prj_30.tif")
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_bu2022_r90_merged_prj_30.tif
builtup <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_bu2022_r90_merged_prj_30.tif")
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_ag2022_r90_merged_prj_30.tif
agriculture <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_ag2022_r90_merged_prj_30.tif")

# calculate conversion factor to km2
km2_conversion <- prod(res(forestry)/1000)

# For all threats, calc area where threat is > 0.1
mod_area_fun_high <- function(df){
  df <- df[!is.na(df$value) & df$value > 0.1,]
  sum(df$coverage_fraction)
}
mod_area_fun_low <- function(df){
  df <- df[!is.na(df$value) & df$value > 0 & df$value < 0.1,]
  sum(df$coverage_fraction)
}

tib$Forestry_km2 <- exactextractr::exact_extract(forestry, project_sf, summarize_df = TRUE, fun = mod_area_fun_high) * km2_conversion
tib$Transport_high_km2 <- exactextractr::exact_extract(transport, project_sf, summarize_df = TRUE, fun = mod_area_fun_high) * km2_conversion
tib$Transport_low_km2 <- exactextractr::exact_extract(transport, project_sf, summarize_df = TRUE, fun = mod_area_fun_low) * km2_conversion
tib$Energy_km2 <- exactextractr::exact_extract(energy, project_sf, summarize_df = TRUE, fun = mod_area_fun_high) * km2_conversion
tib$Builtup_km2 <- exactextractr::exact_extract(builtup, project_sf, summarize_df = TRUE, fun = mod_area_fun_high) * km2_conversion
tib$Agriculture_km2 <- exactextractr::exact_extract(agriculture, project_sf, summarize_df = TRUE, fun = mod_area_fun_high) * km2_conversion


### INTACT MODIFIED ###

# Load intact and not-intact
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_2022_r90_merged_prj_30_intact.tif
intact <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_2022_r90_merged_prj_30_intact.tif")
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_2022_r90_merged_prj_30_modified.tif
modified <- rast("C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_2022_r90_merged_prj_30_modified.tif")

# calculate conversion factor to km2
km2_conversion <- prod(res(intact)/1000)

tib$project_intact_km2 <- exactextractr::exact_extract(intact, project_sf, 'sum') * km2_conversion
tib$project_modified_km2 <- exactextractr::exact_extract(modified, project_sf, 'sum') * km2_conversion

write_csv(tib, "output/Tables/project_table.csv")
write_csv(erap, "output/Tables/erap_table.csv")
