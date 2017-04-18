SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  coalesce(pixel_width,2) pixel_width,
  coalesce(map_width,5) map_width,
  coalesce(color, '#888888') color
FROM
  mapping.linework l
JOIN mapping.linework_type t
  ON l.type = t.id
WHERE geometry && ST_Transform(
  ST_MakeEnvelope($1, $2, $3, $4, 4326),
  (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1))

