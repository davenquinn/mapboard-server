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
      ${map_width}*2
    )
  ),
  ${type},
  ${pixel_width},
  ${map_width},
  ${zoom_level}
  )
RETURNING *
)
SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  pixel_width,
  map_width,
  coalesce(color, '#888888') color
FROM newline l
JOIN mapping.linework_type t
  ON l.type = t.id
