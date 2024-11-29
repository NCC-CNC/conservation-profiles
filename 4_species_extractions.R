# Extract species areas to Ecoregion and project

# Code copied from ERAPs
# Note that these tables are using the term "shortfall" whereas the ERAPs now use "protection gap"

# Additional columns are added to demonstrate the projects contribution to species goals

# NOTE: this scripts requires national tifs have been created for all species data
# This is done in the ERAPs using script 5a_species_data_prep.R
# This script is stored in the NCC erap_code github repo

library(sf)
library(terra)
library(exactextractr)
library(tidyr)
library(dplyr)
library(readr)
library(readxl)
library(openxlsx)

terra::gdalCache(size = 16000)

# Load project
project_sf <- st_read("test_project.shp") %>%
  summarise(geometry = st_union(.)) %>%
  st_cast("POLYGON")

# Load CPCAD + NCC layer
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/protected_areas_2024.gdb/cpcad_ncc_dslv_july2024
cpcad_ncc <- st_read("C:/Users/marc.edwards/Documents/gisdata/protected_areas_2024/ProtectedConservedArea.gdb", "cpcad_ncc_dslv_july2024")

# Load ecoregions - using terrestrial version of ecoregions for this example
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/ecoregions_dslv_clipped_to_2016_census_boundary.shp
ecoregion_sf <- st_read("C:/Users/marc.edwards/Documents/gisdata/national_ecological_framework/Ecoregions/ecoregions_dslv_clipped_to_2016_census_boundary.shp") %>%
  filter(ECOREGION %in% c(96)) %>%
  mutate(geometry = st_union(.))

### open meta data ###
input_data_path <- "C:/Data/PRZ/WTW_DATA/WTW_NAT_DATA_20240522"
species_meta_path <- file.path(input_data_path, "WTW_NAT_SPECIES_METADATA.xlsx")

tibbles <- list()
for(sheet in excel_sheets(species_meta_path)){
  df <- read_excel(species_meta_path, sheet) %>%
    select(c("Source", "File", "Theme", "Sci_Name", "Common_Name", "Threat", "Total_Km2", "Protected_Km2", "Pct_Protected", "Goal"))
  tibbles[[sheet]] <- df
}
species_meta <- bind_rows(tibbles)
names(species_meta)[names(species_meta) == "Total_Km2"] <- "National_Total_Km2"
names(species_meta)[names(species_meta) == "Protected_Km2"] <- "National_Protected_Km2"
names(species_meta)[names(species_meta) == "Pct_Protected"] <- "National_Pct_Protected"
names(species_meta)[names(species_meta) == "Goal"] <- "National_Pct_Goal"
species_meta$National_Pct_Goal <- species_meta$National_Pct_Goal * 100
######################

# Get list of species tif file paths
files <- list.files(file.path("C:/Users/marc.edwards/Documents/PROJECTS/Canada_wide_ecoregion_assessments/processing/species/Tiffs/"), pattern = "^T_.*.tif$", full.names = TRUE)

# load all tiffs 
sp_all <- rast(files)
names(sp_all) <- basename(sources(sp_all))

# Note that these extractions are slow and require a lot of memory
# We don't need to run the extract on all species, only the species intersecting
# the ecoregion. We could do some pre-calculations (e.g. listing ecoregions that each 
# species intersects) that would allow us to filter down the number of extracts.
# For now I'm just running the extract on all species.

# extract values for ecoregion
df_ecoregion <- exactextractr::exact_extract(sp_all, st_union(ecoregion_sf), 'sum') %>%
  pivot_longer(
    cols = colnames(.),
    names_to = "species",
    values_to = "Ecoregion_Total_Km2"
  )

# extract values for PA
ecoregion_pa_sf <- st_intersection(cpcad_ncc, ecoregion_sf)
df_pa <- exactextractr::exact_extract(sp_all, st_union(ecoregion_pa_sf), 'sum') %>%
  pivot_longer(
    cols = colnames(.),
    names_to = "species",
    values_to = "Ecoregion_Protected_Km2"
  )

# extract values for project
project_sf <- st_intersection(project_sf, ecoregion_sf)
df_project <- exactextractr::exact_extract(sp_all, st_union(project_sf), 'sum') %>%
  pivot_longer(
    cols = colnames(.),
    names_to = "species",
    values_to = "Project_Total_Km2"
  )

# join sums
df <- left_join(df_ecoregion, df_pa, by = join_by(species == species)) %>%
  left_join(df_project, by = join_by(species == species)) %>%
  filter(Ecoregion_Total_Km2 > 0)

# remove .sum from names
df$species <- gsub('^sum.', '', df$species)

# convert ECCC data from ha to km2
df$Ecoregion_Total_Km2[grepl('^T_NAT_ECCC', df$species)] <- df$Ecoregion_Total_Km2[grepl('^T_NAT_ECCC', df$species)] / 100
df$Ecoregion_Protected_Km2[grepl('^T_NAT_ECCC', df$species)] <- df$Ecoregion_Protected_Km2[grepl('^T_NAT_ECCC', df$species)] / 100
df$Project_Total_Km2[grepl('^T_NAT_ECCC', df$species)] <- df$Project_Total_Km2[grepl('^T_NAT_ECCC', df$species)] / 100

# join national info from meta data table
out_df <- inner_join(species_meta, df, by = join_by(File == species)) %>%
  mutate(
    National_Km2_Goal = National_Total_Km2 * (National_Pct_Goal/100),
    National_Shortfall_Km2 = National_Km2_Goal - National_Protected_Km2,
    Ecoregion_Km2_Goal = (National_Pct_Goal/100) * Ecoregion_Total_Km2,
    Ecoregion_Shortfall_Km2 = Ecoregion_Km2_Goal - Ecoregion_Protected_Km2
  )
out_df$National_Shortfall_Km2[out_df$National_Shortfall_Km2 < 0] <- 0
out_df$Ecoregion_Shortfall_Km2[out_df$Ecoregion_Shortfall_Km2 < 0] <- 0

# Does the project meet any national or Ecoregion shortfall goals?
out_df <- out_df %>%
  mutate(
    National_Shortfall_Met = 
      case_when(
        National_Shortfall_Km2 > 0 & National_Shortfall_Km2 - Project_Total_Km2 <= 0 ~ "Met",
        National_Shortfall_Km2 > 0 & National_Shortfall_Km2 - Project_Total_Km2 > 0 ~ "Not met",
        .default = "NA"
      ),
    Ecoregion_Shortfall_Met = 
      case_when(
        Ecoregion_Shortfall_Km2 > 0 & Ecoregion_Shortfall_Km2 - Project_Total_Km2 <= 0 ~ "Met",
        Ecoregion_Shortfall_Km2 > 0 & Ecoregion_Shortfall_Km2 - Project_Total_Km2 > 0 ~ "Not met",
        .default = "NA"
      )
  )

# reorder columns
out_df <- out_df[, c("Source", 
                     "File", 
                     "Theme", 
                     "Sci_Name", 
                     "Common_Name", 
                     "Threat", 
                     "National_Total_Km2", 
                     "National_Pct_Goal", 
                     "National_Km2_Goal", 
                     "National_Protected_Km2", 
                     "National_Shortfall_Km2", 
                     "Ecoregion_Total_Km2", 
                     "Ecoregion_Km2_Goal", 
                     "Ecoregion_Protected_Km2",
                     "Ecoregion_Shortfall_Km2", 
                     "Project_Total_Km2",
                     "National_Shortfall_Met",
                     "Ecoregion_Shortfall_Met")]

# round
out_df[c(7:16)] <- round(out_df[c(7:16)], 2)


# Create a summary table reporting the following for each source and for all species together:
# Count of species
# Count with National shortfall > 0 
# Count with Ecoregion shortfall > 0
# Count where project contributes to national shortfall
# Count where project contributes to Ecoregion shortfall
# Count where project meets national shortfall
# Count where project meets Ecoregion shortfall
summary_tib <- out_df %>%
  group_by(Source) %>%
  summarise(
    "Count of species in Ecoregion" = n(),
    "Count of species with national shortfall" = sum(National_Shortfall_Km2 > 0),
    "Count of species with ecoregion shortfall" = sum(Ecoregion_Shortfall_Km2 > 0),
    "Count of species in Project" = sum(Project_Total_Km2 > 0),
    "Project contributes to meeting national shortfall" = sum(National_Shortfall_Km2 > 0 & Project_Total_Km2 > 0),
    "Project contributes to meeting Ecoregion shortfall" = sum(Ecoregion_Shortfall_Km2 > 0 & Project_Total_Km2 > 0),
    "Project meets national shortfall" = sum(National_Shortfall_Met == "Met"),
    "Project meets ecoregion shortfall" = sum(Ecoregion_Shortfall_Met == "Met")
  ) %>%
  pivot_longer(cols = colnames(.[2:9])) %>%
  pivot_wider(names_from = Source, values_from = value) %>%
  mutate(Total = rowSums(.[2:10]))
names(summary_tib)[names(summary_tib) == "name"] <- ""

# save excel version with a different worksheet for each species group
source_list <- unique(species_meta$Source) # start with meta data list to make sure order is always the same
source_list <- source_list[source_list %in% unique(out_df$Source)] # subset by the source's that occur in the ecoregion

sheet_list <- list()
sheet_list[["Summary"]] <- summary_tib
for(s in source_list){
  sheet_list[[s]] <- out_df[out_df$Source == s,]
}
write.xlsx(sheet_list, file.path("output/Tables/", paste0("project_species_assessment.xlsx")))
