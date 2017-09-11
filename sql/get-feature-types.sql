SELECT
  trim(id) id,
  name,
  coalesce(color, '#000000') color
FROM
  ${schema~}.${table~}

