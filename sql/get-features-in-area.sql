SELECT
  l.id,
  ST_AsGeoJSON((ST_Dump(geometry)).geom) geom,
  type,
  coalesce(color, '#888888') color
FROM
  linework l
JOIN linework_type ON l.type = linework_type.id
WHERE geometry && ST_MakeEnvelope($1, $2, $3, $4, 4326)
