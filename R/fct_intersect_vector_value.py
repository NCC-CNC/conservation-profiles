import arcpy
#import pandas as pd
#import tomllib
import os
import sys
import uuid

arcpy.env.overwriteOutput = True

# Sets arcpy's output coordinate system to match a reference dataset, so
# vector intersect outputs land in the same projection as the rest of the
# pipeline. Called once from R (02_extract_vector_data.R) right after this
# file is sourced, passing habitat_forest's path from setup.toml -- this
# used to be a hardcoded reference path instead of a config-driven one.
def set_output_projection(reference_path):
    arcpy.env.outputCoordinateSystem = arcpy.Describe(reference_path).spatialReference

# Compute the area or length of an input feature class within a boundary
# polygon, or within the overlap of several boundaries at once (pass a list,
# e.g. [landscape_fc, protected_fc] to get habitat ∩ landscape ∩ protected).
# PairwiseIntersect only accepts two inputs per call, so multiple boundaries
# are applied as a chain of pairwise intersects rather than a single N-way one.
#
# Intermediates are written to arcpy's scratch file geodatabase, not the
# "memory/" workspace: intersects/dissolves into memory/ were non-deterministic
# (identical calls returned different areas, dropping up to ~6% of habitat in
# chained landscape x protected/WTW intersects), with both PairwiseIntersect
# and classic Intersect, parallel processing on or off. Writing to a file gdb
# gave identical results on every repeat. Names carry a per-call tag since the
# scratch gdb, unlike memory/, is shared across concurrently running processes.
def intersect_vector_value(input_fc, boundary):

    # set units based on shape type
    shape_type = arcpy.Describe(input_fc).shapeType
    if shape_type == 'Polygon':
        query = "!shape.area@hectares!"
    elif shape_type == "Polyline":
        query = "!shape.length@kilometers!"
    else:
        sys.exit(f"Unknown shape type\ndataset path: {input_fc}\nshape type: {shape_type}")

    boundaries = boundary if isinstance(boundary, list) else [boundary]

    scratch = arcpy.env.scratchGDB
    tag = uuid.uuid4().hex[:8]
    dissolved = os.path.join(scratch, f"d_{tag}")

    current = input_fc
    intermediates = []
    try:
        for i, b in enumerate(boundaries):
            out = os.path.join(scratch, f"i{i}_{tag}")
            intermediates.append(out)
            current = arcpy.analysis.PairwiseIntersect([current, b], out)

        intermediates.append(dissolved)
        x_d = arcpy.analysis.PairwiseDissolve(current, dissolved)
        x_d = arcpy.management.AddField(x_d, "calculated_value", "DOUBLE")
        x_d = arcpy.management.CalculateField(x_d, "calculated_value", query)

        total = 0
        with arcpy.da.SearchCursor(x_d, ["calculated_value"]) as cursor:
            for r in cursor:
                total += r[0]
    finally:
        for out in intermediates:
            if arcpy.Exists(out):
                arcpy.management.Delete(out)
    return round(total, 4)