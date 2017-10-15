WITH newline AS (
INSERT INTO ${schema~}.${table~}
  (geometry, type, pixel_width, map_width, certainty, zoom_level)
VALUES (
  ST_Multi(
    ST_MakeValid(
      Linework_SnapEndpoints(
        ST_Transform(
          ST_SetSRID(${geometry}::geometry, 4326),
          (SELECT ST_SRID(geometry) FROM ${schema~}.${table~} LIMIT 1)
        ),
        ${snap_width},
        ${snap_types}::text[]
          -- types of accepted features
          ------ pass an empty array to disable snapping
          ------ null to enable uncritically
          ------ and one-element array of values to snap to single layer
      )
    )
  ),
  ${type},
  ${pixel_width},
  ${map_width},
  ${certainty},
  ${zoom_level}
  )
RETURNING *
)
SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  type,
  map_width,
  certainty,
  coalesce(color, '#888888') color,
  false AS erased
FROM newline l
JOIN ${schema~}.linework_type t
  ON l.type = t.id

