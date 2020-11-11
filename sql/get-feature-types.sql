SELECT
  trim(id) id,
  trim(name) AS "name",
  coalesce(trim(color), '#000000') color
FROM
  ${schema~}.${table~}
ORDER BY name;
