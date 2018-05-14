DELETE FROM ${schema~}.${table~}
WHERE id IN (${features:csv})
RETURNING id

