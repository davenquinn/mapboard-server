{existsSync, readFileSync} = require 'fs'

module.exports = ->
  {argv} = require 'yargs'
    .usage '$0 [--schema \"schema\"] [--tiles \"tilelive-config\"] [--srid 4326 ] dbname'
    .option 'srid', {
      describe: "SRID for database features
                 (computed automatically except for at table creation)."
      type: 'integer'
      default: 4326
      }
    .option 'port', {
      describe: "Port on which to serve",
      type: 'integer',
      default: 3006
    }
    .option 'tiles', {
      describe: "A tilelive config URL (or JSON file)
                 to define a tile source. All URLs will
                 be rewritten and mounted at tiles/"
      type: 'string'
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
  {tiles, schema, srid, port} = argv

  if tiles? and tiles.endsWith ".json"
    # Parse tile config if it's a JSON file
    tiles = JSON.parse readFileSync(tiles, 'utf-8')

  return {dbname, srid, schema, tiles, port}

