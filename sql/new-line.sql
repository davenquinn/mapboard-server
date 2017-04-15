INSERT INTO linework (geometry, type) VALUES (
  ST_Multi(ST_SetSRID(ST_GeomFromEWKB(${geometry}), 4326)),
  ${lineType})
RETURNING
  id,
  ST_AsGeoJSON((ST_Dump(geometry)).geom) geom,
  type;
