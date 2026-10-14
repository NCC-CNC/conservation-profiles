build_profile_html_pdf <- function(cp_tabs, output_path,
                                    template_path = file.path(CODE_DIR, "conservation_profile_template.html"),
                                    logo_url = "NCC_Wordmark_E_Logo_KO.png", # resolved by the browser relative to the temp HTML's location (dirname(template_path)), not R's cwd -- keep relative
                                    prototype = FALSE) {

  hdr       <- cp_tabs$header
  intactness <- cp_tabs$intactness
  pressures  <- cp_tabs$pressures
  species    <- cp_tabs$species_summary

  name_map <- c(
    "Forestry footprint"                     = "Forestry",
    "Agriculture footprint"                  = "Agriculture",
    "Transport footprint - higher intensity" = "Transport — higher intensity",
    "Transport footprint - lower intensity"  = "Transport — lower intensity",
    "Energy and mining footprint"            = "Energy and mining",
    "Urban and built up footprint"           = "Urban and built up"
  )

  eco_intact   <- intactness[intactness$Condition == "Intact",  ]
  eco_modified <- intactness[intactness$Condition == "Modified", ]

  # species totals come from the "Total" / "SAR total" rows of the Species Summary table
  species_count <- function(source, col) {
    if (is.null(species)) return(0)
    v <- species[[col]][species$Source == source]
    if (length(v) == 0 || is.na(v[1])) 0 else v[1]
  }
  n_project        <- species_count("Total",     "Project_count")
  n_landscape      <- species_count("Total",     "Landscape_count")
  n_needs_prot     <- species_count("Total",     "National_or_landscape_protection_shortfall")
  n_proj_needs     <- species_count("Total",     "Project_reduces_shortfall")
  n_sar_proj       <- species_count("SAR total", "Project_count")
  n_sar_land       <- species_count("SAR total", "Landscape_count")
  n_sar_needs_prot <- species_count("SAR total", "National_or_landscape_protection_shortfall")
  n_sar_proj_needs <- species_count("SAR total", "Project_reduces_shortfall")

  pres_sorted <- pressures[order(pressures[["% of ecoregion"]], decreasing = TRUE), ]

  eco_pressures <- lapply(seq_len(nrow(pres_sorted)), function(i) {
    list(
      name = unname(name_map[pres_sorted$Pressure[i]]),
      pct  = round(pres_sorted[["% of ecoregion"]][i], 1)
    )
  })

  proj_pressures <- lapply(seq_len(nrow(pres_sorted)), function(i) {
    ha  <- pres_sorted[["Project total (ha)"]][i]
    pct <- pres_sorted[["% of project"]][i]
    list(
      name = unname(name_map[pres_sorted$Pressure[i]]),
      ha   = if (!is.na(ha))  as.integer(round(ha,  0)) else 0L,
      pct  = if (!is.na(pct)) round(pct, 1)             else 0
    )
  })

  # Habitat area rows: name, coverPct, protectedPct, wtwPct, projectHa, projectPct
  hab_area <- if (!is.null(cp_tabs$habitat_area)) {
    lapply(seq_len(nrow(cp_tabs$habitat_area)), function(i) {
      h <- cp_tabs$habitat_area[i, ]
      list(
        name         = tools::toTitleCase(h$Habitat),
        coverPct     = round(h[["% cover in ecoregion"]],      2),
        protectedPct = round(h[["% of habitat protected"]],    2),
        wtwPct       = round(h[["% of habitat overlapping WTW"]], 2),
        projectHa    = round(h[["Project total (ha)"]],         2),
        projectPct   = round(h[["% of project"]],               1)
      )
    })
  } else list()

  # Habitat linear rows: name, ecoregionKm, protectedPct, wtwPct, projectKm
  hab_linear <- if (!is.null(cp_tabs$habitat_linear)) {
    lapply(seq_len(nrow(cp_tabs$habitat_linear)), function(i) {
      h <- cp_tabs$habitat_linear[i, ]
      list(
        name         = tools::toTitleCase(h$Habitat),
        ecoregionKm  = round(h[["Total in ecoregion (km)"]],      2),
        protectedPct = round(h[["% of habitat protected"]],        2),
        wtwPct       = round(h[["% of habitat overlapping WTW"]], 2),
        projectKm    = round(h[["Project total (km)"]],            2)
      )
    })
  } else list()

  report_data <- list(
    prototype       = prototype,
    projectName     = hdr$Project_name,
    ecoregion       = hdr$REGION_NAM,
    ecozone         = hdr$ZONE_NAME,
    assessmentTitle = hdr$landscape_name,
    logoUrl         = logo_url,
    generatedDate   = paste0(months(Sys.Date()), " ", as.integer(format(Sys.Date(), "%d")), ", ", format(Sys.Date(), "%Y")),
    ecoregionData = list(
      stats = list(
        list(label = "Area protected", value = round(hdr$protected_inland_pcnt, 1), unit = "%", color = "yellow"),
        list(label = "WtW priority",   value = round(hdr$wtw_inland_percent,    1), unit = "%", color = "light-green")
      ),
      intactPct   = round(eco_intact[["% of ecoregion"]],   1),
      modifiedPct = round(eco_modified[["% of ecoregion"]], 1),
      pressures   = eco_pressures
    ),
    projectData = list(
      stats = list(
        list(label = "Project area",          value = as.integer(round(hdr$Project_area_ha, 0)), unit = " ha", color = "deep-green",  basis = "calc(27% - 10px)"),
        list(label = "% of landscape",         value = round(hdr[["project_%_of_ecoregion"]], 2), unit = "%",   color = "light-green", basis = "calc(27% - 10px)"),
        list(label = "Where to Work overlap", value = as.integer(round(hdr[["Project_wtw_ha"]], 0)),     unit = " ha", color = "blue",        basis = "calc(46% - 10px)",
             sub = paste0(round(hdr[["%_of_project_in_WTW"]], 1), "% of project"))
      ),
      intactPct   = round(eco_intact[["% of project"]],            1),
      intactHa    = as.integer(round(eco_intact[["Project total (ha)"]],   0)),
      modifiedPct = round(eco_modified[["% of project"]],          1),
      modifiedHa  = as.integer(round(eco_modified[["Project total (ha)"]], 0)),
      pressures   = proj_pressures
    ),
    species = list(
      ecoregion = list(
        total          = n_landscape,
        atRisk         = n_sar_land,
        needProtection = n_needs_prot,
        atRiskNeedProtection = n_sar_needs_prot
      ),
      project = list(
        total          = n_project,
        atRisk         = n_sar_proj,
        needProtection = n_proj_needs,
        atRiskNeedProtection = n_sar_proj_needs
      )
    ),
    habitat = list(
      area   = hab_area,
      linear = hab_linear
    ),
    other = if (!is.null(cp_tabs$other)) {
      lapply(seq_len(nrow(cp_tabs$other)), function(i) {
        row <- cp_tabs$other[i, ]
        pct <- row[["% of project"]]
        list(
          name       = row$Layer,
          value      = as.integer(round(row[["Project value"]], 0)),
          unit       = row$Unit,
          projectPct = if (!is.na(pct)) pct else NULL
        )
      })
    } else list()
  )

  json_str  <- jsonlite::toJSON(report_data, auto_unbox = TRUE, pretty = TRUE)
  html_text <- paste(readLines(template_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")

  html_text <- sub(
    "(?s)/\\* >>> BEGIN_REPORT_DATA[^*]*\\*/.*?/\\* >>> END_REPORT_DATA <<< \\*/",
    paste0("/* >>> BEGIN_REPORT_DATA (pipeline replaces this object) <<< */\n",
           json_str,
           "\n/* >>> END_REPORT_DATA <<< */"),
    html_text,
    perl = TRUE
  )

  # Write temp HTML next to the template so relative paths (fonts/, logo) resolve correctly
  tmp_html <- tempfile(fileext = ".html",
                       tmpdir  = normalizePath(dirname(template_path), mustWork = FALSE))
  on.exit(unlink(tmp_html), add = TRUE)
  writeLines(html_text, tmp_html, useBytes = TRUE)

  # Landscape Letter is declared in @media print inside the template.
  # --no-sandbox: Chrome/Edge's sandbox needs OS-level process isolation that's
  # often blocked under a restricted server/service account, which otherwise
  # crashes the render process mid-print (surfaces as a WebSocket connection
  # reset, not a clean error).
  pagedown::chrome_print(
    tmp_html,
    output = normalizePath(output_path, mustWork = FALSE),
    wait = 5,
    extra_args = c("--disable-gpu", "--no-sandbox")
  )
}
