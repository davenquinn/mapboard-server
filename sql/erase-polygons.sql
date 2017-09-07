WITH eraser AS (
SELECT ST_MakeValid(
  ST_Transform(
    ST_SetSRID(ST_GeomFromGeoJSON(${geometry}), 4326),
    (SELECT ST_SRID(geometry) FROM ${schema~}.polygon LIMIT 1)
  )) AS geom
),
features AS (
SELECT
  *,
  ST_CoveredBy(l.geometry, e.geom) is_covered
FROM ${schema~}.polygon l
JOIN eraser e ON ST_Intersects(l.geometry, e.geom)
WHERE l.type = TRIM(${type})
  AND NOT l.hidden
),
updated AS (
UPDATE ${schema~}.polygon l
SET geometry = ST_Multi(ST_Difference(l.geometry, e.geom))
FROM eraser e, features f
WHERE f.id = l.id
  AND NOT f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  false AS erased
),
deleted AS (
DELETE
FROM ${schema~}.polygon l
USING features f
WHERE l.id = f.id
  AND f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
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
  coalesce(t.color, '#888888') color,
  erased
FROM results l
JOIN ${schema~}.polygon_type t
  ON l.type = t.id


