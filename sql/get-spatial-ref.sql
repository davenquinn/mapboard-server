SELECT
 srid,
 auth_name || ':' || auth_srid auth,
 substring(srtext FROM '\"(.*?)\"') description,
 srtext LIKE 'PROJCS[%' projected,
 proj4text proj4
FROM spatial_ref_sys
WHERE srid = Find_SRID(${schema}, 'linework', 'geometry');
