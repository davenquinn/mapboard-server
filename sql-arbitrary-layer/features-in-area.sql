SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  map_width,
  certainty,
  coalesce(color, '#888888') color
FROM
  ${schema~}.${table~} l
JOIN ${schema~}.${table~}_type t
  ON l.type = t.id
WHERE geometry && ST_Transform(
  ST_MakeEnvelope($1, $2, $3, $4, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.${table~} LIMIT 1))
  AND NOT l.hidden

