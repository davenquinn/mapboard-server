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

-- Make sure we aren't dealing with multipolygons
geom := ST_LineMerge(geom);

-- DO for both start and endpoints
-- 0, -1 are point indices to work with
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
  FROM ${data_schema~}.linework l
  WHERE ST_Intersects(l.geometry, buffer)
    AND NOT l.hidden
    AND coalesce((l.type = ANY(types)), true);

  -- We have a geometry to append to
  IF closestPoint IS NOT null THEN
    buffer := ST_Buffer(closestPoint, width);
    geom := ST_Difference(geom, buffer);
    IF ix = -1 THEN
      geom := ST_AddPoint(geom, closestPoint);
    ELSE
      geom := ST_AddPoint(geom, closestPoint, 0);
    END IF;
  END IF;
END LOOP;

RETURN geom;

END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

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
