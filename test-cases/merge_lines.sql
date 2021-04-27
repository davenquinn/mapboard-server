INSERT INTO ${schema~}.linework (geometry, type, map_width)
VALUES
(ST_Multi('SRID=32611;LINESTRING(0 0, 1 0)'), 'bedrock-contact', 0.2),
(ST_Multi('SRID=32611;LINESTRING(1 0, 2 0)'), 'bedrock-contact', 0.2),
(ST_Multi('SRID=32611;LINESTRING(2 0, 2.05 0.05)'), 'bedrock-contact', 0.2), -- A dangling edge
(ST_Multi('SRID=32611;LINESTRING(3 0, 2 0)'), 'bedrock-contact', 0.1),
(ST_Multi('SRID=32611;LINESTRING(3 0, 4 0)'), 'bedrock-contact', 0.2),
(ST_Multi('SRID=32611;LINESTRING(3 0, 4 1)'), 'bedrock-contact', 0.1),
(ST_Multi('SRID=32611;LINESTRING(4 0, 5 0, 6 1)'), 'bedrock-contact', 0.1),
(ST_Multi('SRID=32611;LINESTRING(5 0, 6 0)'), 'bedrock-contact', 0.1);
