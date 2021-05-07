DROP FUNCTION IF EXISTS ${data_schema~}.Linework_SnapEndpoints(geometry,numeric,text[]);
DROP TYPE IF EXISTS ${data_schema~}.snapping_returntype;

CREATE TYPE ${data_schema~}.snapping_returntype AS (
  geometry   geometry,
  start_snapped boolean,
  end_snapped boolean,
  err_message text,
  err_context text
);

CREATE OR REPLACE FUNCTION ${data_schema~}.Linework_SnapEndpoints(
  input geometry,
  width numeric,
  types text[]
)
RETURNS ${data_schema~}.snapping_returntype AS
$$
DECLARE
point geometry;
buffer geometry;
geom geometry;
closestPoint geometry;
res geometry;
ix int;
start_snapped boolean;
end_snapped boolean;
ret ${data_schema~}.snapping_returntype;
err_context text;

BEGIN

  -- Make sure we aren't dealing with multipolygons
  geom := ST_LineMerge(input);
  start_snapped := false;
  end_snapped := false;

  -- DO for both start and endpoints
  -- 0, -1 are point indices to work with
  FOREACH ix IN ARRAY ARRAY[0,-1]
  LOOP
    IF ix = 0 THEN
      point := ST_StartPoint(geom);
    ELSE
      point := ST_EndPoint(geom);
    END IF;

    -- do buffering using geography so that we always are working in meters
    buffer := ST_Buffer(point::geography, width)::geometry;

    SELECT
      ST_ClosestPoint(ST_Intersection(l.geometry, buffer), point)
    INTO closestPoint
    FROM ${data_schema~}.linework l
    WHERE ST_Intersects(l.geometry, buffer)
      AND NOT l.hidden
      AND coalesce((l.type = ANY(types)), true);

    -- We have a geometry to append to
    IF closestPoint IS NOT null THEN
      buffer := ST_Buffer(closestPoint::geography, width)::geometry;
      geom := ST_Difference(geom, buffer);
      IF ix = -1 THEN
        geom := ST_AddPoint(geom, closestPoint);
        end_snapped := true;
      ELSE
        geom := ST_AddPoint(geom, closestPoint, 0);
        start_snapped := true;
      END IF;
    END IF;
  END LOOP;

  -- Construct our record set
  SELECT
    ST_Multi(ST_MakeValid(geom)) geometry,
    start_snapped,
    end_snapped,
    null,
    null
  INTO ret;

  RETURN ret;

EXCEPTION WHEN others THEN
  GET STACKED DIAGNOSTICS err_context = PG_EXCEPTION_CONTEXT;

  -- Construct an error record set
  SELECT
    ST_Multi(ST_MakeValid(ST_LineMerge(input))),
    false,
    false,
    SQLERRM,
    err_context
  INTO ret;

  RETURN ret;

END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;
