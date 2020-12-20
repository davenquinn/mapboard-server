WITH f AS (
-- transform input geometry to right SRID
SELECT ST_Transform(
  ST_SetSRID(${geometry}::geometry, 4326),
  ${schema~}.Polygon_SRID()
) AS bounds
)
SELECT
  l.id,
  l.type,
  coalesce(ST_CoveredBy(l.geometry, e.geom), false) is_covered
FROM ${schema~}.${table~} l
WHERE geometry && (SELECT bounds FROM f)
  AND ST_Intersects(geometry, (SELECT bounds FROM f))
  -- The below line sets which features are selected.
  -- The value `types` can be set to the following:
  --  `null`: Any type will be selected
  -- An empty array: no types will be selected (a no-op).
  -- An array of types: types in that array will be erased.
  AND coalesce(l.type = ANY(${types}::text[]), true);