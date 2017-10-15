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

  opts.schema ?= 'public'
  opts.table ?= 'dataset_feature'

  ## Prepare SQL queries
  dn = path.join __dirname,'sql-arbitrary-layer'
  sql = {}
  for fn in readdirSync(dn)
    key = path.basename(fn,'.sql')
    _ = path.join(dn,fn)
    sql[key] = pgp.QueryFile _, {
      minify: true, debug: true, params: {schema, table}
    }

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
    # Right now we are just disabling snapping by
    # fiat. We need to make sure we are always working
    # in a reasonable coordinate system if snapping
    # is enabled.
    # I suppose that the user can be expected to provide
    # the data in a meters-based coordinate system for interoperability
    # with snapping code? IDK. Or snapping can be accomplished in the
    # EPSG:3857 frame...
    #
    # TODO: Figure out best practices for this.
    if true #snappingDisabled
      p.snap_types ?= []
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

    # We can only erase a single type for now
    db.query sql["erase-#{procName}"], {geometry, types}
      .map serializeFeature
      .tap console.log
      .then send(res)

  app.post "/line/erase", erase("lines")
  app.post "/polygon/erase", erase("polygons")

  getTypes = -> (req, res)->
    # Right now we only have a concept of types that maps
    # directly to layers, with no added data provided.
    res = [{id: table, name: table, color: '#000000'}]
    send(res)


  app.get "/line/types", getTypes()
  app.get "/polygon/types", getTypes()

  return app

