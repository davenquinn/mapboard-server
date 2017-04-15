CREATE OR REPLACE FUNCTION Linework_SnapEndpoints(geom geometry, width numeric)
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
  FROM mapping.linework l
  WHERE ST_Intersects(l.geometry, buffer);

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
