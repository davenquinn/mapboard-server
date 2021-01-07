/*
A basic insert statement for running tests.
Does not manipulate coordinate reference systems etc.
*/

INSERT INTO ${schema~}.${table~} (geometry, type )
VALUES (
  ST_Multi(ST_SetSRID(${geometry}::geometry, ${srid})),
  ${type}
)
RETURNING *
