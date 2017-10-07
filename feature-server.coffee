express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
PGPromise = require('pg-promise')
path = require 'path'
{readdirSync} = require 'fs'
{serializeFeature, parseGeometry, send} = require './util'
colors = require 'colors'

logFunc = (e)->
  console.log e.query
  if e.params?
    console.log "    "+e.params

pgp = PGPromise(promiseLib: Promise, query: logFunc)

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

  app.post "/line/features-in-area", (req, res)->
    env = req.body.envelope
    db.query sql['get-lines-in-area'], env
      .map serializeFeature
      .then send(res)

  app.post "/polygon/features-in-area", (req, res)->
    env = req.body.envelope
    db.query sql['get-polygons-in-area'], env
      .map serializeFeature
      .then send(res)

  # Set up routes
  app.post "/line/new",(req, res)->
    f = req.body
    p = f.properties
    p.snap_types ?= null
    p.snap_width ?= 2*map_width

    data = {
      geometry: parseGeometry(f)
      p...
    }

    console.log data
    db.query sql['new-line'], data
      .map serializeFeature
      .tap console.log
      .then send(res)

  # Set up routes
  app.post "/polygon/new",(req, res)->
    f = req.body
    {properties} = f
    geometry = parseGeometry(f)
    {allow_overlap} = properties
    allow_overlap ?= false
    erased = []
    if not allow_overlap
      # Null for 'types' erases all types
      erased = await db.query sql['erase-polygons'], {geometry, types: null}
        .map serializeFeature

    data = await db.query sql['new-polygon'], {geometry, properties...}
      .map serializeFeature

    newRes = data.concat erased
    # If we don't want overlap
    Promise.resolve(newRes)
      .then send(res)

  app.post "/line/delete", (req, res)->
    db.query sql['delete-line'], id: req.body.id
      .then send(res)

  app.post "/polygon/delete", (req, res)->
    db.query sql['delete-polygon'], id: req.body.id
      .then send(res)

  erase = (procName)->(req, res)->
    # Erase features given a geojson polygon
    # Returns a list of replaced features
    f = req.body
    geometry = parseGeometry f
    {erase_types} = f.properties
    types = erase_types or null

    db.query sql["erase-#{procName}"], {geometry, types}
      .map serializeFeature
      .tap console.log
      .then send(res)

  app.post "/line/erase", erase("lines")
  app.post "/polygon/erase", erase("polygons")

  app.get "/line/types", (req, res)->
    db.query sql['get-feature-types'], {table: 'linework_type'}
      .then send(res)

  app.get "/polygon/types", (req, res)->
    db.query sql['get-feature-types'], {table: 'polygon_type'}
      .then send(res)

  return app

