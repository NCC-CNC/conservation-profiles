# These scripts take a project polygon and prep an assessment matching the ERAPs
# The goal is to use the ERAPs to identify what the ecoregion needs in terms of
# conservation actions and protection.
# Then to evaluate whether the project addresses any of those needs.

# These scripts are intended to be copied into a new R project for each project being assessed

# Set up output folder structure

dir.create("output")
dir.create("output/Tables")
dir.create("output/Maps")