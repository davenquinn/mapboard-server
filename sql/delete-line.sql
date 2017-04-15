DELETE FROM mapping.linework
WHERE id = ${id} RETURNING id
