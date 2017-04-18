WITH eraser AS (
SELECT ST_Transform(
  ST_SetSRID(ST_GeomFromGeoJSON(${geometry}), 4326),
  (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1)) AS geom
),
features AS (
SELECT
  *,
  ST_CoveredBy(l.geometry, e.geom) is_covered
FROM mapping.linework l
JOIN eraser e ON ST_Intersects(l.geometry, e.geom)
WHERE l.type = ${type}
),
updated AS (
UPDATE mapping.linework l
SET geometry = ST_Multi(ST_Difference(l.geometry, e.geom))
FROM eraser e, features f
WHERE f.id = l.id
  AND NOT f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  false AS erased
),
deleted AS (
DELETE
FROM mapping.linework l
USING features f
WHERE l.id = f.id
  AND f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  true AS erased
),
results AS (
SELECT * FROM updated
UNION ALL
SELECT * FROM deleted
)
SELECT
  l.id,
  l.geometry,
  l.type,
  coalesce(l.pixel_width,2) pixel_width,
  coalesce(l.map_width,5) map_width,
  coalesce(t.color, '#888888') color,
  erased
FROM results l
JOIN mapping.linework_type t
  ON l.type = t.id

