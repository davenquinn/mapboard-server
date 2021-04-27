WITH f AS (
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  ${schema~}.Polygon_SRID()
) AS bounds
)
SELECT
  id,
  ST_Transform(ST_SetSRID(geom, 3857), 4326) geometry,
  unit_id AS "type",
  2 map_width,
  null certainty,
  coalesce(color, '#888888') color
FROM ${schema~}.unit_outcrop
WHERE geometry && (SELECT bounds FROM f)
  AND ST_Intersects(geometry, (SELECT bounds FROM f))

