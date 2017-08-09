{argv} = require 'yargs'
  .usage '$0 [--schema \"schema\"] [--srid 4326 ] dbname'
  .option 'srid', {
    describe: "SRID for database features
               (computed automatically except for at table creation)."
    type: 'integer'
    default: 4326
    }
  .option 'schema', {
    describe: "Schema for tables"
    type: 'string'
    default: 'map_digitizer'
    }
  .help 'h'
  .alias 'h','help'

if argv._.length != 1
  console.error "Must specify a database"
  process.exit()

## Set up options
dbname = argv._[0]
srid = argv.srid # Use WGS84 lat/lon by default
schema = argv.schema

module.exports = {dbname, srid, schema}

