WITH newline AS (
INSERT INTO ${schema~}.${table~}
  (geometry)
VALUES (
  ST_Multi(
    ST_MakeValid(
      ${table~}_SnapEndpoints(
        ST_Transform(
          ST_SetSRID(${geometry}::geometry, 4326),
          (SELECT ST_SRID(geometry) FROM ${schema~}.${table~} LIMIT 1)
        ),
        ${snap_width}
      )
    )
  )
)
RETURNING *
)
SELECT
  l.id,
  ST_Transform(geometry, 4326) geometry,
  ${map_width} map_width,
  false AS erased
FROM newline l
