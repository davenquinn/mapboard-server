WITH eraser_polygon AS (
  SELECT ST_Transform(
    ST_SetSRID(${geometry}::geometry, 4326),
    ${schema~}.Linework_SRID()
  ) AS geom
),
topo_eraser AS (
  SELECT ST_Union(e.geom) geom
  FROM map_topology.edge e
  JOIN map_topology.__edge_relation er
  ON e.edge_id = er.edge_id
  JOIN eraser_polygon eA ON ST_Intersects(e.geom, eA.geom)
),
features AS (
SELECT
  *,
  (
    ST_CoveredBy(l.geometry, e.geom)
    OR ST_Equals(l.geometry, (SELECT geom FROM topo_eraser))
  ) is_covered
FROM ${schema~}.linework l
JOIN eraser_polygon e ON ST_Intersects(l.geometry, e.geom)
-- The below line sets which features are erased.
-- The value `types` can be set to the following:
--  `null`: Any type will be erased
-- An empty array: no types will be erased (a no-op).
-- An array of types: types in that array will be erased.
WHERE coalesce(l.type = ANY(${types}::text[]), true)
  AND NOT l.hidden
),
updated AS (
UPDATE ${schema~}.linework l
SET geometry = ST_Multi(ST_Difference(l.geometry, (SELECT geom FROM topo_eraser)))
FROM features f
WHERE l.id = f.id
  AND NOT f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  l.certainty,
  false AS erased
),
deleted AS (
DELETE
FROM ${schema~}.linework l
USING features f
WHERE l.id = f.id
  AND f.is_covered
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  l.certainty,
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
  l.map_width,
  l.certainty,
  coalesce(t.color, '#888888') color,
  erased
FROM results l
JOIN ${schema~}.linework_type t
  ON l.type = t.id
