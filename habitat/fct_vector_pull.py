
def vector_pull(vector, boundary, col_name, uid_col):
  
  vector_name = arcpy.Describe(vector).name
  boundary_name = arcpy.Describe(boundary).name
  geometry_type = arcpy.Describe(vector).shapeType
  
  if geometry_type == "Polygon":
    unit = "SHAPE@AREA"
    unit_conversion = 10000 # m2 to ha
  elif geometry_type == "Polyline":
    unit = "SHAPE@LENGTH"
    unit_conversion = 1000 # m to km
  else: 
    raise ValueError("Error: unsupported geometry type: {}".format(geometry_type))
  
  # Intersection habitat to aoi
  print("... Intersecting {} to {}".format(vector_name, boundary_name))
  feat_x = arcpy.analysis.PairwiseIntersect([boundary, vector], "memory/i")
  
  # Build dimension dictionary (ha or km)
  print("... Building habitat dictionary")
  dim = {}
  with arcpy.da.SearchCursor(feat_x, [uid_col, unit]) as cursor:
      for row in cursor:
          _id, measure = row[0], row[1]
          if _id not in dim:
              dim[_id] = round((measure / unit_conversion), 2) # round to 2 decimal
          else:
              dim[_id] += round((measure / unit_conversion), 2) # round to 2 decimal
  
  # Join dim dictionary to aoi attribute 
  print("... Joining habitat")
  arcpy.management.AddField(boundary, col_name, "DOUBLE")
  with arcpy.da.UpdateCursor(boundary, [uid_col, col_name]) as cursor:
      for row in cursor:
          _id = row[0]
          if _id in dim:
              row[1] = dim[_id]
          else:
              row[1] = 0
          cursor.updateRow(row)  
  
