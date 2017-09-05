express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
pgp = require('pg-promise')(promiseLib: Promise)
path = require 'path'
wkx = require 'wkx'
{Buffer} = require 'buffer'
{readdirSync} = require 'fs'

## Support functions ##

serializeFeature = (r)->
  _ = new Buffer(r.geometry,'hex')
  geom = wkx.Geometry.parse(_).toGeoJSON()
  feature = {
    type: 'Feature'
    geometry: geom
    properties:
      type: r.type
      color: r.color
      pixel_width: r.pixel_width
      map_width: r.map_width
    id: r.id
  }

  # Handle erasing transparently-ish
  # with an extension to the GeoJSON protocol
  r.erased ?= false
  if r.erased
    feature =
      type: 'DeletedFeature'
      id: r.id

  console.log feature.type
  return feature

parseGeometry = (f)->
  # Parses a geojson feature to geometry
  wkx.Geometry.parseGeoJSON(f.geometry).toEwkb()

send = (res)->
  (data)->res.send(data)

module.exports = (opts)->
  {dbname, schema} = opts
  db = pgp "postgres:///#{dbname}"
  app = express()
  app.use bodyParser.json()

  opts.schema ?= 'map_digitizer'

  ## Prepare SQL queries
  dn = path.join __dirname,'sql'
  sql = {}
  for fn in readdirSync(dn)
    key = path.basename(fn,'.sql')
    _ = path.join(dn,fn)
    sql[key] = pgp.QueryFile _, minify: true, debug: true, params: {schema}

  db.query sql['snap-function']
    .then -> console.log "SQL functions are set up!!!"

  app.post "/features-in-area", (req, res)->
    env = req.body.envelope
    db.query sql['get-features-in-area'], env
      .map serializeFeature
      .then send(res)

  # Set up routes
  app.post "/new-line",(req, res)->
    f = req.body
    data =
      geometry: f.geometry
      type: f.properties.type
      pixel_width: f.properties.pixel_width
      map_width: f.properties.map_width
      zoom_level: f.properties.zoom_level

    db.one sql['new-line'], data
      .tap console.log
      .then serializeFeature
      .then send(res)

  app.post "/delete", (req, res)->
    db.query sql['delete-line'], id: req.body.id
      .then send(res)

  app.post "/erase", (req, res)->
    # Erase features given a geojson polygon
    # Returns a list of replaced features
    f = req.body
    data =
      geometry: f.geometry
      type: f.properties.type
    db.query sql['erase-lines'], data
      .map serializeFeature
      .tap console.log
      .then send(res)

  app.get "/line/types", (req, res)->
    db.query sql['get-feature-types'], {table: 'linework_type'}
      .then send(res)

  app.get "/polygon/types", (req, res)->
    db.query sql['get-feature-types'], {table: 'polygon_type'}
      .then send(res)

  return app

