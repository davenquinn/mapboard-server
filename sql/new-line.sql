WITH snap_result AS (
  SELECT ((${schema~}.Linework_SnapEndpoints(
    ST_Transform(
      ST_SetSRID(${geometry}::geometry, 4326),
      ${schema~}.Linework_SRID()
    ),
    ${snap_width},
    ${snap_types}::text[]
      -- types of accepted features
      ------ pass an empty array to disable snapping
      ------ null to enable uncritically
      ------ and one-element array of values to snap to single layer
  )).*)
), newline AS (
INSERT INTO ${schema~}.linework
  (geometry, type, pixel_width, map_width, certainty, zoom_level)
VALUES (
  snap_result.geometry,
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
  false AS erased,
  s.start_snapped,
  s.end_snapped,
  s.err_message
FROM
  newline l,
  snap_result s
JOIN ${schema~}.linework_type t
  ON l.type = t.id
