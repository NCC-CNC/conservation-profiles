# Script to calcualte the area or length of habitat in project

# Workflow:
  # For project
    # Intersect feature with project
    # Dissolve
    # Calculate area

import arcpy
import os

arcpy.env.overwriteOutput = True

### SETUP ################################

# Set up - DW
CONSP_DATA_MARC = "C:/Data/PRZ/Conservation_Profiles_Data"
PROJECT_ROOT = "C:/Data/PRZ/CONSP"
PROJECT_FOLDER = "TEST"
PROJECT_DIR = os.path.join(PROJECT_ROOT, PROJECT_FOLDER)

# Set input paths
project_path = "{}/aoi/test_project.shp".format(PROJECT_DIR)

# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Grassland/ Processing.gdb/RasterToPoly/AAFC_LUTS_2020
grassland_path = "{}/habitat_metrics_Jul24_2024/habitat.gdb/AAFC_LUTS_2020".format(CONSP_DATA_MARC)
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Wetland/ Processing.gdb/canvec_saturated_soil_2_merge_20230201_pw_dissolve
wetland_path = "{}/habitat_metrics_Jul24_2024/habitat.gdb/canvec_saturated_soil_2_merge_20230201_pw_dissolve".format(CONSP_DATA_MARC)
# S drive location: S:/CONS_TECH/PRZ/DATA/PREP/Habitat/Lakes/ _archive/Z_DELETE/Waterbody.gdb/waterbody_2_proj_diss
lakes_path = "{}/habitat_metrics_Jul24_2024/habitat.gdb/waterbody_2_proj_diss".format(CONSP_DATA_MARC)
# S drive location: S:/hydrology_data_temp_location/NHN/master_rivers.gdb/master_rivers
rivers_path = "{}/habitat_metrics_Jul24_2024/master_rivers.gdb/master_rivers".format(CONSP_DATA_MARC)
# Merged version of shorelines not currently on S drive. Need to merge the data in R:/NCCGIS/DATA/NRCAN/CanCoast/CanCoast_v1/CanCoast.gdb/CanCoast_shoreline_ver1_0 and R:/NCCGIS/DATA/ECCC/SHORELINE/ShorelineClassification_ON_OpenDataCatalogue.gdb/O14Oceans_ShorelineClass_ON
shoreline_path = "{}/habitat_metrics_Jul24_2024/habitat.gdb/shoreline_merge".format(CONSP_DATA_MARC)


# # Set output paths
# if not arcpy.Exists("C:/temp/habitat.gdb"):
#     arcpy.CreateFileGDB_management("C:/temp", "habitat.gdb")

if not arcpy.Exists("{}/habitat/habitat.gdb".format(PROJECT_DIR)):
    hab_fgdb = arcpy.CreateFileGDB_management("{}/habitat".format(PROJECT_DIR), "habitat.gdb")

# Set prj
ncc_prj = "{}/habitat_metrics_Jul24_2024/Forest_LC_30m_2022.tif".format(CONSP_DATA_MARC)
arcpy.env.outputCoordinateSystem = arcpy.Describe(ncc_prj).spatialReference


for h in ["grassland", "wetland", "lakes", "shoreline", "rivers"]:

    print("Processing..." + h)

    # Set paths
    clip_project = "{}/intersect_{}_project_clip".format(hab_fgdb, h) 
    clip_project_dslv = "{}/{}_project".format(hab_fgdb, h)

    # Set parameters    
    if h == "grassland":
        h_path = grassland_path
        colname = "grassland_km2"
        query = "!shape.area@squarekilometers!"
    if h == "wetland":
        h_path = wetland_path
        print("repairing geometry..")
        #arcpy.management.MultipartToSinglepart(h_path, "C:/temp/habitat.gdb/wetland_dslv") # got an invalid topology error that needs fixing. Dissolve and RepairGeometry didn't work. Exploding did. Run this line the first time script runs
        # h_path = "C:/temp/habitat.gdb/wetland_dslv"
        colname = "wetland_km2"
        query = "!shape.area@squarekilometers!"
    if h =="lakes":
        h_path = lakes_path
        colname = "lakes_km2"
        query = "!shape.area@squarekilometers!"
    if h =="rivers":
        h_path = rivers_path
        colname = "rivers_km"
        query = "!shape.length@kilometers!"
    if h =="shoreline":
        h_path = shoreline_path
        colname = "shoreline_km"
        query = "!shape.length@kilometers!"


    ### PROJECT #######################

    # Clip habitat to the project
    print("clip...")
    arcpy.analysis.PairwiseClip(h_path, project_path, clip_project)
    arcpy.analysis.PairwiseDissolve(clip_project, clip_project_dslv)
    arcpy.management.DeleteField(clip_project_dslv, colname)
    arcpy.management.AddField(clip_project_dslv, colname + "_project", "DOUBLE")
    arcpy.management.CalculateField(clip_project_dslv, colname + "_project", query)

    
    ### EXPORT TABLES FOR FASTER READING IN R ###
    print("export tables...")
    print(clip_project_dslv)
    arcpy.conversion.TableToTable(clip_project_dslv, hab_fgdb, "{}_project_table".format(h))
