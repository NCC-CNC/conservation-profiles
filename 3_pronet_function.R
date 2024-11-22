# ProNet proof of concept for any AOI and proposed project

# Here we general the ProNet score for the existing PAs in the AOI (usually an ecoregion)
# Then we add the project to the PAs and generate ProNet again to see how much the project would increase the ProNet score
# We run it at a range of scales to see how it effects local to regional ProNet scores.

# Note that this implementation is only using euclidean distance in place of ecological distance
# The scripts need to be updated to use ecological distance based on the resistance surface
# coming out of HM. Available in Dave Theobald's google folder.

rm(list = ls(all.names = TRUE))
gc()

library(sf)
library(tidyverse)

#########################################
### make pronet function that takes the prepped PA network and ecological distance in m
#########################################
calc_pronet <- function(pa, d){
  
  pa_buff <- st_buffer(pa, dist = d) %>%
    summarise(geometry = st_union(.)) %>%
    st_cast("POLYGON") %>%
    mutate(id = 1:nrow(.))
  
  pa_clustered <- st_join(pa, pa_buff, left = TRUE) %>%
    mutate(area_km2 = as.numeric(st_area(.)/1000000))
  
  clusters <- pa_clustered %>%
    st_drop_geometry() %>%
    group_by(id) %>%
    summarise(pa_clust_km2 = sum(area_km2))
  
  return(sum(clusters$pa_clust_km2^2) / sum(clusters$pa_clust_km2)^2)
  
  #st_write(pa_buff, "C:/temp/pa_buff.shp", append=FALSE)
  #st_write(pa_clustered, "C:/temp/pa_clustered.shp", append=FALSE)
  
}
#########################################


# Open project, dissolve and explode
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/Dans_updated_WTW_Includes_July_2024/Existing_Conservation.tif
project_sf <- st_read("test_project.shp") %>%
  summarise(geometry = st_union(.)) %>%
  st_cast("POLYGON")

# Load CPCAD + NCC layer
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/protected_areas_2024.gdb/cpcad_ncc_dslv_july2024
cpcad_ncc <- st_read("C:/Users/marc.edwards/Documents/gisdata/protected_areas_2024/ProtectedConservedArea.gdb", "cpcad_ncc_dslv_july2024")

# Load AOI - using terrestrial version of ecoregions hfor this example
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/ecoregions_dslv_clipped_to_2016_census_boundary.shp
aoi_ecoregion <- st_read("C:/Users/marc.edwards/Documents/gisdata/national_ecological_framework/Ecoregions/ecoregions_dslv_clipped_to_2016_census_boundary.shp") %>%
  filter(ECOREGION %in% c(96)) %>%
  mutate(geometry = st_union(.))

# Prep a 20km, 50km and a 100km circle as additional AOIs
centroid <- st_centroid(st_union(project_sf))
aoi_20km_buffer <- st_buffer(centroid, dist = 20*1000)
aoi_50km_buffer <- st_buffer(centroid, dist = 50*1000)
aoi_100km_buffer <- st_buffer(centroid, dist = 100*1000)

# Create a table to view results
tib_pronet <- tibble("AOI" = as.character(), "scenario" = as.character(), "ecological distance" = as.numeric(), "ProNet" = as.numeric())

for(aoi_name in c("aoi_ecoregion", "aoi_20km_buffer", "aoi_50km_buffer", "aoi_100km_buffer")){
  
  # get object from name
  aoi <- get(aoi_name)
  
  # make vector of ecological distances to run, specific to each aoi
  d_list <- case_when(aoi_name == "aoi_ecoregion" ~ list(c(3000, 10000, 30000, 100000)),
                      aoi_name == "aoi_20km_buffer" ~ list(c(3000)),
                      aoi_name == "aoi_50km_buffer" ~ list(c(3000, 10000)),
                      aoi_name == "aoi_100km_buffer" ~ list(c(3000, 10000, 30000))
  ) %>% .[[1]]
  
  # prep the two protected area scenarios for pronet
  
  # 1 - CPCAD + NCC
  pa_1 <- st_intersection(cpcad_ncc, aoi) %>%
    summarise(geometry = st_union(.)) %>%
    st_cast("POLYGON")
  
  # 2 - CPCAD + NCC + proposed project
  pa_2 <- st_intersection(rbind(pa_1, project_sf), aoi) %>%
    summarise(geometry = st_union(.)) %>%
    st_cast("POLYGON")
  
  for(d in d_list){
    
    tib_pronet <- rbind(tib_pronet, 
                        tibble("AOI" = aoi_name, "scenario" = "Existing PAs", "ecological distance (km)" = d/1000, "ProNet" = calc_pronet(pa_1, d)),
                        tibble("AOI" = aoi_name, "scenario" = "Existing PAs + new project", "ecological distance (km)" = d/1000, "ProNet" = calc_pronet(pa_2, d))
    )
  }
}

# Save
write_csv(tib_pronet, "output/Tables/pronet.csv")
st_write(aoi_20km_buffer, "output/Maps/vectors.gdb", "pronet_aoi_20km_buffer")
st_write(aoi_50km_buffer, "output/Maps/vectors.gdb", "pronet_aoi_50km_buffer")
st_write(aoi_100km_buffer, "output/Maps/vectors.gdb", "pronet_aoi_100km_buffer")

