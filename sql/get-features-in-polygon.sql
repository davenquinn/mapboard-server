WITH f AS (
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.polygon LIMIT 1)
) AS bounds
)
SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  map_width,
  certainty,
  coalesce(color, '#888888') color
FROM ${schema~}.${table~} l
JOIN ${schema~}.${type_table~} t
  ON l.type = t.id
WHERE geometry && (SELECT bounds FROM f)
  AND ST_Intersects(geometry, (SELECT bounds FROM f))
