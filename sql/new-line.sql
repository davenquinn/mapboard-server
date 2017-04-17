WITH newline AS (
INSERT INTO mapping.linework
  (geometry, type, pixel_width, map_width, zoom_level)
VALUES (
  ST_Multi(
    Linework_SnapEndpoints(
      ST_Transform(
        ST_SetSRID(ST_GeomFromGeoJSON(${geometry}), 4326),
        (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1)
      ),
      ${map_width}
    )
  ),
  ${type},
  ${pixel_width},
  ${map_width},
  ${zoom_level}
  )
RETURNING *
),
rows AS (
SELECT
  l.id,
  ST_Dump(ST_Transform(geometry, 4326)) geometries,
  type,
  pixel_width,
  map_width,
  coalesce(color, '#888888') color
FROM newline l
JOIN mapping.linework_type t
  ON l.type = t.id
)
SELECT
  id,
  ST_AsGeoJSON((geometries).geom) geometry,
  (geometries).path part,
  type,
  pixel_width,
  map_width,
  color
FROM rows;
