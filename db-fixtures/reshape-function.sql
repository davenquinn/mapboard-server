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
  map_digitizer.Linework_SRID()
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
out reshape_result;
BEGIN

-- Get the intersecting linework
SELECT ST_MakeValid(ST_LineMerge(ST_Union(l.geometry)))
INTO subject
FROM map_digitizer.linework l
WHERE ST_Intersects(l.geometry, blade)
  AND NOT l.hidden
  AND l.type = linework_type;

SELECT array_agg(l.id)
INTO out.deleted
FROM map_digitizer.linework l
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

SELECT ST_Multi(ST_LineMerge(ST_Union(ARRAY[start, middle, tail]::geometry[])))
INTO out.result;

RETURN out;

-- EXCEPTION WHEN others THEN
--   SELECT null INTO out.result;
--   SELECT ARRAY[]::integer[] INTO out.deleted;
--   RETURN out;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;
