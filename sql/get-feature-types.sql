SELECT
  trim(id) id,
  trim(name) AS "name",
  coalesce(color, '#000000') color
FROM
  ${schema~}.${table~}
ORDER BY name;

