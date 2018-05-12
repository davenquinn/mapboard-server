UPDATE map_digitizer.${table~}
SET type = ${type}
WHERE id IN (${features:csv})
RETURNING (id, type)
