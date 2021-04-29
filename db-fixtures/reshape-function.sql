/* Utility functions */
CREATE OR REPLACE FUNCTION ${data_schema~}.Linework_SRID()
RETURNS integer AS
$$
SELECT srid FROM geometry_columns
WHERE f_table_schema = ${data_schema}
  AND f_table_name = 'linework'
  AND f_geometry_column = 'geometry'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION ${data_schema~}.Polygon_SRID()
RETURNS integer AS
$$
SELECT srid FROM geometry_columns
WHERE f_table_schema = ${data_schema}
  AND f_table_name = 'polygon'
  AND f_geometry_column = 'geometry'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION ${data_schema~}.endpoint_intersections(geom geometry)
RETURNS bigint[]
AS
$$
SELECT ARRAY[
  (SELECT count(*)-1 FROM ${data_schema~}.linework l WHERE ST_Intersects(l.geometry, ST_StartPoint(ST_LineMerge(geom)))),
  (SELECT count(*)-1 FROM ${data_schema~}.linework l WHERE ST_Intersects(l.geometry, ST_EndPoint(ST_LineMerge(geom))))
];
$$ LANGUAGE SQL IMMUTABLE;

/* Reshaping */

DROP TYPE IF EXISTS reshape_result CASCADE;
CREATE TYPE reshape_result AS (
  result geometry,
  deleted integer[],
  exception text
);

CREATE OR REPLACE FUNCTION Geom_Transform(geom geometry)
RETURNS geometry AS
$$
SELECT ST_Transform(
  ST_SetSRID(geom, 4326),
  ${data_schema~}.Linework_SRID()
)
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION minimum(anyarray)
RETURNS anyelement as $$
select min($1[i]) from generate_series(array_lower($1,1),
array_upper($1,1)) g(i);
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION Linework_Reshape(
  blade geometry,
  tolerance numeric, -- How much to heal lines by, if applicable
  linework_type text -- Line type to snap to
)
RETURNS reshape_result AS
$$
DECLARE
subject geometry;
intersection geometry;
n_points integer;
start_point geometry;
end_point geometry;
subj_distances numeric[];
d1 numeric;
d2 numeric;
start geometry;
middle geometry;
tail geometry;
grid_size float;
out reshape_result;
BEGIN

grid_size := 0.0000001;

-- Get the intersecting linework
SELECT ST_MakeValid(ST_LineMerge(ST_Union(l.geometry)))
INTO subject
FROM ${data_schema~}.linework l
WHERE ST_Intersects(l.geometry, blade)
  AND NOT l.hidden
  AND l.type = linework_type;

SELECT array_agg(l.id)
INTO out.deleted
FROM ${data_schema~}.linework l
WHERE ST_Intersects(l.geometry, blade)
  AND NOT l.hidden
  AND l.type = linework_type;

-- Get the intersection of the cutting
-- blade and the relevant linework
SELECT ST_Intersection(subject, blade) INTO intersection;

n_points := ST_NPoints(intersection);

start_point := ST_GeometryN(intersection, 1);
end_point := ST_GeometryN(intersection, n_points);

-- Apply distancing along subject
BEGIN
  d1 := ST_LineLocatePoint(subject, start_point);
  d2 := ST_LineLocatePoint(subject, end_point);
EXCEPTION WHEN others THEN
  -- We are in a more complex case where we want to manage multiple points
  RAISE ERROR 'reshaping did not work: %', others;
  SELECT null INTO out.result;
  SELECT ARRAY[]::integer[] INTO out.deleted;
  RETURN out;
END;

IF d1 < d2 THEN
  start := ST_LineSubstring(subject, 0, d1);
  tail := ST_LineSubstring(subject, d2, 1);
ELSE
  start := ST_LineSubstring(subject, 0, d2);
  tail := ST_LineSubstring(subject, d1, 1);
END IF;

-- Apply distancing along blade
d1 := ST_LineLocatePoint(blade, start_point);
d2 := ST_LineLocatePoint(blade, end_point);
IF d1 < d2 THEN
  middle := ST_LineSubstring(blade, d1, d2);
ELSE
  middle := ST_LineSubstring(blade, d2, d1);
END IF;

SELECT ST_Multi(ST_LineMerge(ST_Union(ARRAY[
  ST_SnapToGrid(start, grid_size),
  ST_SnapToGrid(middle, grid_size),
  ST_SnapToGrid(tail, grid_size)
]::geometry[])))
INTO out.result;

RETURN out;

-- EXCEPTION WHEN others THEN
--   SELECT null INTO out.result;
--   SELECT ARRAY[]::integer[] INTO out.deleted;
--   RETURN out;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;
