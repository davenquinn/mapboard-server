WITH f AS (
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  ${schema~}.Polygon_SRID()
) AS bounds
)
SELECT
  l.id,
  ST_Transform(
    ST_Simplify(
      ST_Transform(geometry, 3857),
      ZRes(${zoom_level}::integer)*${simplify_factor}::numeric
    ),
    4326
  ) geometry,
  type,
  map_width,
  certainty,
  coalesce(color, '#888888') color
FROM ${schema~}.${table~} l
JOIN ${schema~}.${type_table~} t
  ON l.type = t.id
WHERE geometry && (SELECT bounds FROM f)
  AND ST_Intersects(geometry, (SELECT bounds FROM f))
