WITH a AS (
SELECT ST_Transform(a.geom, (SELECT ST_SRID(geometry) FROM mapping.linework LIMIT 1)) geometry
)
UPDATE mapping.linework l
SET geometry = ST_Difference(l.geometry, b.geometry)
FROM b
WHERE ST_Intersects(b.geometry, l.geometry)
