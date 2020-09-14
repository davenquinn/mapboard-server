/*
Reshaping lines
1. Get all relevant features intersecting buffered area (should be of same type)
2. Join all linework usign ST_LineMerge, which gives us the subject
  - May need to first node the linework and "heal" small dangling lines
3. Cut using the blade geometry, and find a line which intersects both endpoints
  - If multiple, choose the shortest line
4. Replace constituent features with new line
*/
WITH res AS (
  SELECT (Linework_Reshape(Geom_Transform(${geometry}), ${tolerance}, ${type})).*
),
-- We could potentially move some of this logic into the reshape function...
new AS (
  INSERT INTO ${schema~}.linework
    (geometry, type, pixel_width, map_width, certainty, zoom_level)
  SELECT
    result,
    ${type},
    ${pixel_width},
    ${map_width},
    ${certainty},
    ${zoom_level}
  FROM res
  RETURNING
    id,
    geometry,
    type,
    pixel_width,
    map_width,
    certainty,
    false AS erased
),
deleted AS (
DELETE
FROM ${schema~}.linework l
USING res
WHERE l.id = ANY( res.deleted )
RETURNING
  l.id,
  l.geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  l.certainty,
  true AS erased
),
results AS (
SELECT * FROM new
UNION ALL
SELECT * FROM deleted
)
SELECT
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  coalesce(l.pixel_width,2) pixel_width,
  l.map_width,
  l.certainty,
  coalesce(t.color, '#888888') color,
  erased
FROM results l
JOIN ${schema~}.linework_type t
  ON l.type = t.id
