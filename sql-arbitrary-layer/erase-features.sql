WITH eraser AS (
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.${table~} LIMIT 1)) AS geom
),
features AS (
SELECT
  *,
  ST_CoveredBy(l.geometry, e.geom) is_covered
FROM ${schema~}.${table~} l
JOIN eraser e ON ST_Intersects(l.geometry, e.geom)
-- The below line sets which features are erased.
-- The value `types` can be set to the following:
--  `null`: Any type will be erased
-- An empty array: no types will be erased (a no-op).
-- An array of types: types in that array will be erased.
-- NOTE: this doesn't really matter for arbitrary layers
-- unless we set up a field to group on.
),
updated AS (
UPDATE ${schema~}.${table~} l
SET geometry = ST_Difference(l.geometry, e.geom)
FROM eraser e, features f
WHERE f.id = l.id
  AND NOT f.is_covered
RETURNING
  l.id,
  ST_Multi(ST_Transform(l.geometry, 4326)) geometry,
  false AS erased
),
deleted AS (
DELETE
FROM ${schema~}.${table~} l
USING features f
WHERE l.id = f.id
  AND f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  true AS erased
)
SELECT * FROM updated
UNION ALL
SELECT * FROM deleted

