# Conservation Profiles

Generates a Conservation Profile (an Excel workbook + a landscape-format PDF report) for a project boundary polygon: habitat cover, pressures (footprint), protection status, Where-to-Work (WTW) overlap, and species range/protection stats, all compared against a reference landscape.

The reference landscape is one of:
- **Default** — the ecoregion the majority of the project falls in (looked up automatically from `ERAP_ecoregions.gdb`).
- **Forced ecoregion(s)** — one or more ecoregion IDs you specify directly (e.g. to combine two adjacent ecoregions into one comparison landscape).
- **Custom landscape** — any polygon you provide (e.g. an IPCA boundary, a planning region) instead of an ecoregion. The ERAP-equivalent stats and species table are computed on the fly for that polygon instead of looked up.

Regardless of which reference landscape is used, the project's own real ecoregion/ecozone (`ECOREGION`, `REGION_NAM`, `ECOZONE`, `ZONE_NAME`, etc.) are always shown in the report — the reference landscape only changes what the project's stats are being *compared against*.

Note that custom landscapes take significantly longer to process. Up to 1 hr for large landscapes compared to 1-2 minutes for default or forced ecoregions.

## Running in the shared workspace (GIS Data Workshop)

This codebase lives in **one shared, git-synced location** (`CODE_DIR`) rather than being copied per project. Only two small, per-project files live outside it: `run.R` (copied from `run_template.R`) and `setup.toml` (copied from `setup_template.toml`).

**One-time, per machine: (managed by CPP)**
1. Clone/pull this repo to a fixed location (e.g. `C:/GIS/conservation-profiles`) — this is `CODE_DIR`.
2. Edit `arcgis_config.toml` in `CODE_DIR` and set `python_path` to this machine's ArcGIS Pro Python environment (the one with a licensed `arcpy`), e.g.:
   ```toml
   python_path = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe"
   ```
   If you're not sure where this is, it's typically under ArcGIS Pro's install directory at `bin/Python/envs/arcgispro-py3/python.exe`.

**Per project:**
1. Create a new folder for the project (anywhere — it does not need to be inside `CODE_DIR`).
2. Copy `run_template.R` from the repo root into that folder and rename it `run.R`.
3. Open `run.R` (right click the file and 'open with' RStudio or Positron) and confirm `CODE_DIR` points at the shared checkout from step 1 (this should already match — it's the same for every project on a given machine, so it normally needs no edits). Then set `toml_path` to this project's own `setup.toml` full file path — this must be set manually for every project; it is not derived automatically.
4. Copy `setup_template.toml` from the repo root into that folder, rename it `setup.toml`, open in RStudio or Positron and update the `[project]` fields (and `[custom_landscape]`, if using one) with this project's paths — see below.
5. Run `run.R` in RStudio or Positron. It sources `__pipeline__.R` from `CODE_DIR` and `setup.toml` from the path you set in step 3.

Outputs (`<project_name>_conservation_profile.xlsx`/`.pdf`) are written to `project_dir` as set in `setup.toml` — this can be the project folder itself or anywhere else.

Notes on running in GIS Data Workshop:
- This workflow uses the arcpy library which requires an active ArcGIS license. To activate your license, open and log in to ArcGIS Pro before running the code.
- `run.R`'s `toml_path` must be updated to point at the current project's `setup.toml` every time you switch projects.
- The first time you run this workflow, R will need to install all the packages to you GIS Data Workshop profile. This will add some processing time. The first time the codebase builds the conservation profile pdf, you may get an admin permission request popup. This can be cancelled, the pdf is still built and the popup doesn't appear for subsequent runs.


## `setup_template.toml` reference

Fields you set per project (after copying the template to `setup.toml`):

| Section | Field | Notes |
|---|---|---|
| `[project]` | `project_name`, `project_dir`, `project_path` | Your project's display name, output folder, and boundary polygon. |
| `[custom_landscape]` | `landscape_name`, `landscape_path` | Optional — leave `landscape_path` blank to use the default ecoregion lookup instead. |

Everything else (`[paths]`, `[habitat_raster]`, `[pressures_raster]`, `[habitat_vector]`, `[prioritization_raster]`, `[other_raster]`, `[other_vector]`, `[custom_landscape_data]`) points at the fixed reference datasets on the server and normally doesn't need to change between projects.

## Pipeline steps

Driven by `R/__pipeline__.R`, in order:

1. **01 Setup** (`R/01_setup.R`) — installs any missing R packages, reads `setup.toml`, reprojects `project_path` (and a custom `landscape_path`, if set) to match the reference data's projection if needed.
2. **Landscape setup** (`R/fct_landscape_setup.R`) — resolves which of the three reference-landscape modes above is in effect.
3. **02 Vector extractions** (`R/02_extract_vector_data.R`) — intersects the project against habitat vector layers (grassland, wetland, lakes, rivers, shoreline) via arcpy (through `reticulate`).
4. **03 Raster extractions** (`R/03_extract_raster_data.R`) — intersects the project against habitat/pressure/WTW rasters.
5. **Other layers** — peatlands, carbon storage.
6. **04 Species** (`R/04_build_species_tab.R`) — species range/protection stats, either from precomputed per-ecoregion CSVs or computed on the fly for a custom landscape.
7. **05 Excel** (`R/05_build_profile_excel.R`) — assembles all of the above into the Conservation Profile Excel workbook.
8. **06 PDF** (`R/06_build_profile_html.R`) — renders the same data into the HTML template (`conservation_profile_template.html`) and prints it to PDF.

## Requirements

- Windows, R 4.4+ (packages auto-install on first run).
- ArcGIS Pro installed with a licensed `arcpy` (used for vector intersections via `reticulate`) — the Python environment path is set in `arcgis_config.toml` (see "Running in the shared workspace" below).
- Access to the fixed-path reference datasets (habitat, pressures, WTW, protected areas, species rasters, `ERAP_ecoregions.gdb`) referenced in `setup_template.toml`.


