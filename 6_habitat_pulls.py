
def vector_pull(vector, boundary, col_name):
  
  file_name = arcpy.Describe(vector).name
  geometry_type = arcpy.Describe(vector).shapeType
  oid_field = arcpy.Describe(vector).OIDFieldName
  
  if geometry_type == "Polygon":
    measure = "SHAPE@AREA"
    unit_conversion = 10000 # m2 to ha
  elif geometry_type == "Polyline":
    measure = "SHAPE@LENGTH"
    unit_conversion = 1000 # m to km
  else: 
    raise ValueError(f"Error: unsupported geometry type: {}".format(geometry_type))
  
  # Intersection to create gridded includes
  print("Intersecting {} to {}".format(vector, boundary))
  feat_x = arcpy.analysis.PairwiseIntersect([feature, boundary], "memory/i")
  
  # Build dictionary: HA
  dim = {}
  with arcpy.da.SearchCursor(feat_x, [oid_field, feat_x]) as cursor:
      for row in cursor:
          id, measure = row[0], row[1]
          if id not in ha:
              ha[id] = round(measure / unit_conversion, 2) # round to 2 decimal
          else:
              ha[id] += round(area / unit_conversion, 2) # round to 2 decimal
  
  # Join HA dictionary to gridded includes attribute table 
  arcpy.management.AddField(boundary, col_name, "DOUBLE")
  with arcpy.da.UpdateCursor(boundary, [oid_field, col_name]) as cursor:
      for row in cursor:
          id = row[0]
          if id in dim:
              row[1] = dim[id]
          else:
              row[1] = 0
          cursor.updateRow(row)  
  
