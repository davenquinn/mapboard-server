CREATE OR REPLACE FUNCTION Linework_SnapEndpoints(
  geom geometry,
  width numeric,
  types text[]
)
RETURNS geometry AS
$$
DECLARE
point geometry;
buffer geometry;
closestPoint geometry;
res geometry;
ix int;

BEGIN
 -- DO for both start and endpoints
FOREACH ix IN ARRAY ARRAY[0,-1]
LOOP
  IF ix = 0 THEN
    point := ST_StartPoint(geom);
  ELSE
    point := ST_EndPoint(geom);
  END IF;

  buffer := ST_Buffer(point, width);

  SELECT
    ST_ClosestPoint(ST_Intersection(l.geometry, buffer), point)
  INTO closestPoint
  FROM ${schema~}.linework l
  WHERE ST_Intersects(l.geometry, buffer)
    AND NOT l.hidden
    AND coalesce((l.type = ANY(types)), true);

  -- We have a geometry to append to
  IF closestPoint IS NOT null THEN
    buffer := ST_Buffer(closestPoint, width);
    geom := ST_Difference(geom, buffer);
    geom := ST_AddPoint(geom, closestPoint, ix);
  END IF;

END LOOP;

RETURN geom;

END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

CREATE OR REPLACE FUNCTION ${schema~}.Linework_SRID()
RETURNS integer AS
$$
SELECT srid FROM geometry_columns
WHERE f_table_schema = ${schema}
  AND f_table_name = 'linework'
  AND f_geometry_column = 'geometry'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION ${schema~}.Polygon_SRID()
RETURNS integer AS
$$
SELECT srid FROM geometry_columns
WHERE f_table_schema = ${schema}
  AND f_table_name = 'polygon'
  AND f_geometry_column = 'geometry'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION ${schema~}.endpoint_intersections(geom geometry)
RETURNS bigint[]
AS
$$
SELECT ARRAY[
  (SELECT count(*)-1 FROM ${schema~}.linework l WHERE ST_Intersects(l.geometry, ST_StartPoint(ST_LineMerge(geom)))),
  (SELECT count(*)-1 FROM ${schema~}.linework l WHERE ST_Intersects(l.geometry, ST_EndPoint(ST_LineMerge(geom))))
];
$$ LANGUAGE SQL IMMUTABLE;

