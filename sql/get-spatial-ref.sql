SELECT * FROM spatial_ref_sys
WHERE srid = Find_SRID(${schema}, 'linework', 'geometry');
