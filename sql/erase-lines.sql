WITH eraser AS (
SELECT ST_Transform(
  ST_SetSRID(ST_GeomFromGeoJSON(${geometry}), 4326),
  (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1)) AS geom
),
updated AS (
UPDATE mapping.linework l
SET geometry = ST_Multi((ST_Dump(ST_Difference(l.geometry, eraser.geom))).geom)
FROM eraser
WHERE ST_Intersects(l.geometry, eraser.geom)
  AND l.type = ${type}
RETURNING *
),
rows AS (
SELECT
  l.id,
  ST_Dump(ST_Transform(l.geometry, 4326)) geometries,
  type,
  coalesce(pixel_width,2) pixel_width,
  coalesce(map_width,1) map_width,
  coalesce(color, '#888888') color
FROM updated l
JOIN mapping.linework_type t
  ON l.type = t.id
)
SELECT
  id,
  ST_AsGeoJSON((geometries).geom) geometry,
  (geometries). part,
  type,
  pixel_width,
  map_width,
  color
FROM rows;
