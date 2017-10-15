DELETE FROM ${schema~}.${table~}
WHERE id = ${id} RETURNING id
