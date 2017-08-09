{argv} = require 'yargs'

if argv._.length != 1
  console.error "Must specify a database"
  process.exit()

## Set up options
dbname = argv._[0]
srid = argv.srid or 4326 # Use WGS84 lat/lon by default
schema = argv.schema or 'map_digitizer'

module.exports = {dbname, srid, schema}

