SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  coalesce(color, '#888888') color
FROM
  ${schema~}.polygon l
JOIN ${schema~}.polygon_type t
  ON l.type = t.id
WHERE geometry && ST_Transform(
  ST_MakeEnvelope($1, $2, $3, $4, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.polygon LIMIT 1))
  AND NOT l.hidden

