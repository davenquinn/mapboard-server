DELETE FROM ${schema~}.linework
WHERE id = ${id} RETURNING id
