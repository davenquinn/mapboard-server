/*
Reshaping lines
1. Get all relevant features intersecting buffered area (should be of same type)
2. Join all linework usign ST_LineMerge, which gives us the subject
  - May need to first node the linework and "heal" small dangling lines
3. Cut using the blade geometry, and find a line which intersects both endpoints
  - If multiple, choose the shortest line
4. Replace constituent features with new line
*/
SELECT
  (Linework_Reshape(Geom_Transform(${geometry}), ${tolerance}, ${type})).result geometry,
  id AS type,
  2 map_width,
  2 pixel_width,
  color
FROM map_digitizer.linework_type
WHERE id = ${type};
