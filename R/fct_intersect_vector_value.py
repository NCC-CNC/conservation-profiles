import arcpy
#import pandas as pd
#import tomllib
import sys

arcpy.env.outputCoordinateSystem = arcpy.Describe("C:/Users/marc.edwards/Documents/gisdata/habitat_metrics_Jul24_2024/habitat.gdb/waterbody_2_proj_diss").spatialReference
arcpy.env.overwriteOutput = True

# Compute the area or length of an input feature class within a boundary
# polygon, or within the overlap of several boundaries at once (pass a list,
# e.g. [landscape_fc, protected_fc] to get habitat ∩ landscape ∩ protected).
# PairwiseIntersect only accepts two inputs per call, so multiple boundaries
# are applied as a chain of pairwise intersects rather than a single N-way one.
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

    current = input_fc
    intermediates = []
    for i, b in enumerate(boundaries):
        out = f"memory/i{i}"
        current = arcpy.analysis.PairwiseIntersect([current, b], out)
        intermediates.append(out)

    x_d = arcpy.analysis.PairwiseDissolve(current, "memory/d")
    x_d = arcpy.management.AddField(x_d, "calculated_value", "DOUBLE")
    x_d = arcpy.management.CalculateField(x_d, "calculated_value", query)

    total = 0
    with arcpy.da.SearchCursor(x_d, ["calculated_value"]) as cursor:
        for r in cursor:
            total += r[0]
    for out in intermediates:
        arcpy.management.Delete(out)
    arcpy.management.Delete("memory/d")
    return round(total, 4)