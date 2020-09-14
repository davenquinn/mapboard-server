DROP TYPE IF EXISTS reshape_result CASCADE;
CREATE TYPE reshape_result AS (
  result geometry,
  deleted integer[]
);

CREATE OR REPLACE FUNCTION Geom_Transform(geom geometry)
RETURNS geometry AS
$$
SELECT ST_Transform(
  ST_SetSRID(geom, 4326),
  map_digitizer.Linework_SRID()
)
$$ LANGUAGE SQL IMMUTABLE;


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
cut_points geometry;
out reshape_result;
BEGIN

-- Get the intersecting linework
SELECT l.geometry
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

-- Get the intersection of the cutting blade and the relevant linework
SELECT ST_Intersection(subject, blade)
INTO intersection;

n_points := ST_NPoints(intersection);

-- intersection := ST_MakeLine(intersection);
cut_points := ST_Collect(ST_GeometryN(intersection, 1), ST_GeometryN(intersection, n_points));

subject := ST_Split(subject, intersection);
blade := ST_Split(blade, cut_points);

--SELECT ST_GeometryN(intersection, n_points) INTO out.result;

SELECT ST_LineMerge(ST_Collect(ARRAY[
    ST_GeometryN(subject,1),
    ST_GeometryN(blade, 2),
    ST_GeometryN(subject,3)
  ])) INTO out.result;

RETURN out;

END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;
