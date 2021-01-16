UPDATE map_digitizer.linework
SET geometry = ST_Reverse(geometry)
WHERE id IN (${features:csv})
RETURNING
  id,
  ST_Transform(geometry, 4326) geometry,
  type,
  map_width,
  certainty,
  -- right now color isn't used, so we can punt on fixing it...
  '#888888' color;