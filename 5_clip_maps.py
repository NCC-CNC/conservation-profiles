# Clip all input data to AOI for ease of interpretation
# Long term, this might not be needed if we have a centralized map viewer

import arcpy
from arcpy.sa import *

arcpy.env.overwriteOutput = True

### SETUP ################################

# Set prj
ncc_prj = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/Forest_LC_30m_2022.tif" # This needs to point to any file with the NCC Albers prj
arcpy.env.outputCoordinateSystem = arcpy.Describe(ncc_prj).spatialReference

# Create output gdb for vectors
out = "../output/Maps/vectors.gdb"
if not arcpy.Exists(out):
    arcpy.CreateFileGDB_management("../output/Maps", "vectors.gdb")

# Prep the AOI boundary
print("Prep AOI...")
# S drive location: S:/ERAPs/output/ERAP_ecoregions.gdb/ERAP_ecoregions
ecoregions_path = "C:/Users/marc.edwards/Documents/gisdata/national_ecological_framework/Ecoregions/ecoregions.shp" # use the full ecoregion feature here so we can see all the data
aoi = out + "/aoi"

eco_list = 96

query = """{0} = {1}""".format(arcpy.AddFieldDelimiters(ecoregions_path, 'ECOREGION'), str(eco_list)) # for single ecoregion
ecoregions = arcpy.management.SelectLayerByAttribute(ecoregions_path, "NEW_SELECTION", query)
arcpy.management.Dissolve(ecoregions, aoi)


# Set all source data paths

# vectors
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/protected_areas_2024.gdb/cpcad_ncc_dslv_july2024
cpcad_ncc_protected = "C:/Users/marc.edwards/Documents/gisdata/protected_areas_2024/ProtectedConservedArea.gdb/cpcad_ncc_dslv_july2024"
project_boundary = "../test_project.shp"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Grassland/Processing.gdb/RasterToPoly/AAFC_LUTS_2020
grassland_path = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/habitat.gdb/AAFC_LUTS_2020"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Wetland/Processing.gdb/canvec_saturated_soil_2_merge_20230201_pw_dissolve
wetland_path = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/habitat.gdb/canvec_saturated_soil_2_merge_20230201_pw_dissolve"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Lakes/_archive/Z_DELETE/Waterbody.gdb/waterbody_2_proj_diss
lakes_path = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/habitat.gdb/waterbody_2_proj_diss"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/shoreline.gdb/shoreline_merge
shoreline_path = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/habitat.gdb/shoreline_merge"
# S drive location: S:/hydrology_data_temp_location/NHN/master_rivers.gdb/master_rivers
rivers_path = "C:/Users/marc.edwards/Documents/gisdata/hydrology/NHN/master_rivers.gdb/master_rivers"

# tifs
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/Canada_wtw_2024.tif
where_to_work_prioritization = "C:/Users/marc.edwards/Documents/PROJECTS/Canada_wide_ecoregion_assessments/processing/prioritizr/ecozones/Canada_wtw_2024.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/NAT_1KM/biod/rich/biod_rich.tif
species_biodiversity_count = "C:/Data/PRZ/WTW_DATA/WTW_NAT_DATA_20240522/biodiversity/richness/BOID_COUNT.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/NAT_1KM/biod/rich/sar_rich.tif
species_sar_count = "C:/Data/PRZ/WTW_DATA/WTW_NAT_DATA_20240522/biodiversity/richness/ECCC_SAR_COUNT.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Forest/Forest_LC_30m_2022.tif
habitat_forests = "C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/Forest_LC_30m_2022.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_2022_r90_merged_prj_30_intact.tif
intact_land = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_2022_r90_merged_prj_30_intact.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_2022_r90_merged_prj_30_modified.tif
modified_land = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_2022_r90_merged_prj_30_modified.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_fr2022_r90_merged_prj_30.tif
threat_forestry = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_fr2022_r90_merged_prj_30.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_tr2022_r90_merged_prj_30.tif
threat_transport = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_tr2022_r90_merged_prj_30.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_en2022_r90_merged_prj_30.tif
threat_energy = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_en2022_r90_merged_prj_30.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_bu2022_r90_merged_prj_30.tif
threat_builtup = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_bu2022_r90_merged_prj_30.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_ag2022_r90_merged_prj_30.tif
threat_agriculture = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_ag2022_r90_merged_prj_30.tif"
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/xCANADA_WIDE_SOURCE/HM_CA_2022_r90_merged_prj_30.tif
threat_human_modification = "C:/Users/marc.edwards/Documents/gisdata/Canada_human_modification/HM_Aug21_2024_projected_30m/HM_CA_2022_r90_merged_prj_30.tif"


### PROCESSING ################################
'''
# Copy in the project boundary
print("Project boundary...")
arcpy.conversion.FeatureClassToFeatureClass(project_boundary, out, "project_boundary")

# Clip PAs
print("PAs...")
arcpy.analysis.Clip(cpcad_ncc_protected, aoi, out + "/cpcad_ncc_protected")

# Clip habitat vectors 
print("Clip habitat...")
arcpy.analysis.Clip(grassland_path, aoi, out + "/habitat_grassland")
arcpy.analysis.Clip(wetland_path, aoi, out + "/habitat_wetland")
arcpy.analysis.Clip(lakes_path, aoi, out + "/habitat_lakes")
arcpy.analysis.Clip(rivers_path, aoi, out + "/habitat_rivers")
arcpy.analysis.Clip(shoreline_path, aoi, out + "/habitat_shoreline")
'''
# Clip all rasters to AOI
print("Clip rasters...")
arcpy.Clip_management(where_to_work_prioritization, "", "../output/Maps/where_to_work_prioritization.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(species_biodiversity_count, "", "../output/Maps/species_biodiversity_count.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(species_sar_count, "", "../output/Maps/species_sar_count.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(habitat_forests, "", "../output/Maps/habitat_forests.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(intact_land, "", "../output/Maps/intact_land.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(modified_land, "", "../output/Maps/modified_land.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_forestry, "", "../output/Maps/threat_forestry.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_transport, "", "../output/Maps/threat_transport.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_energy, "", "../output/Maps/threat_energy.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_builtup, "", "../output/Maps/threat_builtup.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_agriculture, "", "../output/Maps/threat_agriculture.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")
arcpy.management.Clip(threat_human_modification, "", "../output/Maps/threat_human_modification.tif", in_template_dataset = aoi, clipping_geometry = "ClippingGeometry")


