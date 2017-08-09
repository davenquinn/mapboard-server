DELETE FROM map_digitizer.linework
WHERE id = ${id} RETURNING id
