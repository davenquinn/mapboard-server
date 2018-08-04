/*
This query is designed to get polygons filled during
topological healing of a geologic map. The overall structure is similar
to that of the other feature-returning functions in `get-features-in-polygon.sql`,
except that there is no `map_width` column returned. It might be desireable to
unify these queries into one file.
*/
WITH f AS (
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.polygon LIMIT 1)
) AS bounds
)
SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  unit_id AS type,
  coalesce(color, '#888888') color
FROM ${topology_schema~}.${table~} l
JOIN ${topology_schema~}.${type_table~} t
  ON l.type = t.id
WHERE geometry && (SELECT bounds FROM f)
  AND ST_Intersects(geometry, (SELECT bounds FROM f))

