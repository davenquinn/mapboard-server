WITH eraser AS (
SELECT ST_Transform(
  ST_SetSRID(ST_GeomFromEWKB(${geometry}), 4326),
  (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1)) geometry
),
updated AS (
UPDATE mapping.linework l
SET geometry = ST_Difference(l.geometry, eraser.geometry)
FROM eraser
WHERE ST_Intersects(l.geometry, eraser.geometry)
  AND l.type = ${type}
RETURNING *
)
SELECT
  l.id,
  ST_AsGeoJSON(
    (ST_Dump(
      ST_Transform(geometry, 4326)
      )).geom
  ) geometry,
  type,
  map_width,
  coalesce(color, '#888888') color
FROM updated l
JOIN mapping.linework_type t
  ON l.type = t.id
