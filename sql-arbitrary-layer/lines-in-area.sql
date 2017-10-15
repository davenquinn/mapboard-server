SELECT
  l.id,
  ST_Multi(ST_Transform(geometry, 4326)) geometry
FROM
  ${schema~}.${table~} l
WHERE geometry && ST_Transform(
  ST_MakeEnvelope($1, $2, $3, $4, 4326),
  (SELECT ST_SRID(geometry) FROM ${schema~}.${table~} LIMIT 1))
  AND ST_Dimension(geometry) = 1

