DELETE FROM ${schema~}.polygon
WHERE id = ${id} RETURNING id

