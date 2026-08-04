# Get intersecting ecoregion
source("R/fct_read_feature.R")

get_landscape_id <- function(project_path, landscape_path, identifier_col) {

  print("Getting landscape id")
  project_sf <- read_feature(project_path) |> sf::st_union() |> sf::st_as_sf()
  landscape_sf <- read_feature(landscape_path)

  intersections <- sf::st_intersection(project_sf, landscape_sf)
  intersections$overlap_area <- as.numeric(sf::st_area(sf::st_geometry(intersections))) / 10000 # convert m2 to ha
  landscape_id <- intersections[[identifier_col]][intersections$overlap_area == max(intersections$overlap_area)] # return the landscape i.d. with the largest overlap with project

  return(landscape_id)

}

# Returns the distinct ecoregions (id + names + ecozone) that boundary_sf
# genuinely overlaps by area, joined from erap_path's attribute table --
# unlike get_landscape_id() (which returns only the single largest-overlap
# ecoregion), this returns every ecoregion with real overlapping area. Used to
# identify which real ecoregion(s)/ecozone(s) a project sits in (e.g. for
# header display), independent of whatever landscape it's being compared against.
#
# st_intersection() between two polygon layers can return a degenerate
# zero-area LINESTRING/POINT for a pair that only shares a boundary edge (e.g.
# a project clipped exactly to one ecoregion's boundary also technically
# "touches" its neighbours along that edge) -- filtered out here via a
# relative-area threshold (0.1% of boundary_sf's own area) rather than an
# absolute one, so it scales with project size and tolerates small
# vertex-alignment slivers between independently-built datasets.
get_overlapping_ecoregions <- function(boundary_sf, erap_path) {
  ecoregions_sf <- sf::st_transform(read_feature(erap_path), sf::st_crs(boundary_sf))
  overlap_sf <- sf::st_intersection(ecoregions_sf, boundary_sf)

  boundary_area <- as.numeric(sf::st_area(boundary_sf))
  overlap_sf <- overlap_sf[as.numeric(sf::st_area(overlap_sf)) / boundary_area > 0.001, ]

  cols <- c("ECOREGION", "REGION_NAM", "REGION_NOM", "ECOZONE", "ZONE_NAME", "ZONE_NOM")
  overlap_df <- unique(sf::st_drop_geometry(overlap_sf)[cols])
  overlap_df[order(overlap_df$ECOREGION), ]
}