SELECT
  id,
  ST_AsGeoJSON((ST_Dump(geometry)).geom) geom,
  type
FROM
  editable_linework
WHERE geometry && ST_MakeEnvelope($1, $2, $3, $4, 4326)
