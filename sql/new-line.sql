WITH newline AS (
INSERT INTO ${schema~}.linework
  (geometry, type, pixel_width, map_width, zoom_level)
VALUES (
  ST_Multi(
    ST_MakeValid(
      Linework_SnapEndpoints(
        ST_Transform(
          ST_SetSRID(ST_GeomFromGeoJSON(${geometry}), 4326),
          (SELECT ST_SRID(geometry) FROM ${schema~}.linework LIMIT 1)
        ),
        ${map_width}*2
      )
    )
  ),
  TRIM(${type}),
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
  coalesce(color, '#888888') color,
  false AS erased
FROM newline l
JOIN ${schema~}.linework_type t
  ON l.type = t.id

