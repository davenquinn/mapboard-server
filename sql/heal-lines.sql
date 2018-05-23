WITH candidate_lines AS (
  SELECT * FROM ${schema~}.linework
  WHERE id IN (${features:csv})
    AND type = ${type}
),
del_initial AS (
-- We should delete candidate lines that are already too small
-- for our cutoff size and don't intersect other geometries
  SELECT id
  FROM candidate_lines m
  WHERE ST_Length(geometry) < ${tolerance}
  AND (SELECT min(n_ends) FROM unnest(${schema~}.endpoint_intersections(m.geometry)) n_ends) = 0
),
merged_lines AS (
  SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom geometry
  FROM candidate_lines l
  GROUP BY l.type
),
merged_lines2 AS (
SELECT (ST_Dump(ST_LineMerge(ST_Union(geometry)))).geom geometry
FROM merged_lines m, unnest(${schema~}.endpoint_intersections(m.geometry)) n_ends
WHERE NOT (
  ST_Length(m.geometry) < ${tolerance}
  AND (SELECT min(n_ends) FROM unnest(${schema~}.endpoint_intersections(m.geometry)) n_ends) = 0
  )
),
lines2 AS (
SELECT m.geometry geometry, c.id, c.geometry old_geometry
FROM merged_lines2 m
JOIN candidate_lines c
  ON ST_Intersects(m.geometry, c.geometry)
 AND NOT ST_Touches(m.geometry, c.geometry)
-- Get rid of small dangling edges
),
lines3 AS (
-- Keep line parts that are already part of the same line together
SELECT
  id,
  ST_LineMerge(ST_Union(geometry)) geometry
FROM lines2
GROUP BY id
),
lines4 AS (
/*
Get rid of lines that are geometrically equal to current lines
Could probably get rid of short "dangling" edges in this step
*/
SELECT
  l.id, -- all of the features that need to be deleted and merged
  l.geometry
FROM lines3 l
JOIN candidate_lines c
  ON c.id = l.id
WHERE NOT ST_Equals(l.geometry, c.geometry)
),
lines5 AS (
-- Get the longest possible matching geometry
SELECT l1.id, coalesce(l2.geometry, l1.geometry) geometry
FROM lines4 l1
LEFT JOIN lines4 l2
  ON ST_Contains(l2.geometry, l1.geometry)
 AND NOT ST_Equals(l1.geometry, l2.geometry)
),
deleted AS (
-- Same signature as eraser
DELETE FROM ${schema~}.linework l
WHERE id IN (SELECT id FROM lines5 UNION SELECT id FROM del_initial)
RETURNING
  l.id,
  ST_Transform(l.geometry, 4326) geometry,
  l.type,
  l.pixel_width,
  l.map_width,
  l.certainty,
  true AS erased
),
updated AS (
INSERT INTO ${schema~}.linework (geometry, type, map_width, certainty)
SELECT
  ST_Multi(l.geometry) geometry,
  c.type,
  sum(c.map_width*ST_Length(c.geometry)/ST_Length(l.geometry)) map_width, -- length-weighted average
  round(sum(c.certainty*ST_Length(c.geometry)/ST_Length(l.geometry)))::integer certainty
FROM lines5 l
JOIN candidate_lines c
  ON c.id = l.id
GROUP BY (l.geometry, c.type)
RETURNING
  id,
  ST_Transform(geometry, 4326) geometry,
  type,
  (null::numeric) AS pixel_width,
  map_width,
  certainty,
  false AS erased
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
