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
  opts.schema = 'public'
  opts.table = 'dataset_feature'
  {dbname, schema, table} = opts

  snapFunction = "#{schema}.#{table}_LineworkSnap"
  db = pgp "postgres:///#{dbname}"
  app = express()
  app.use bodyParser.json()

  ## Prepare SQL queries
  dn = path.join __dirname,'sql-arbitrary-layer'
  sql = {}
  for fn in readdirSync(dn)
    key = path.basename(fn,'.sql')
    _ = path.join(dn,fn)
    sql[key] = pgp.QueryFile _, {
      minify: true, debug: true, params: {schema, table, snapFunction}
    }

  db.query sql['snap-function']
    .then -> console.log "SQL functions are set up!!!"

  app.post "/line/features-in-area", (req, res)->
    env = req.body.envelope
    db.query sql['lines-in-area'], env
      .map serializeFeature
      .then send(res)

  app.post "/polygon/features-in-area", (req, res)->
    env = req.body.envelope
    db.query sql['polygons-in-area'], env
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
    p.snap_width ?= 2*p.map_width

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
    p = f.properties

    p.snap_width ?= 2*p.map_width

    geometry = parseGeometry(f)
    {allow_overlap} = p
    allow_overlap ?= false
    erased = []
    if not allow_overlap
      erased = await db.query sql['erase-features'], {geometry}
        .map serializeFeature

    data = await db.query sql['new-feature'], {geometry, p...}
      .map serializeFeature

    newRes = data.concat erased
    # If we don't want overlap
    Promise.resolve(newRes)
      .then send(res)

  app.post "/line/delete", (req, res)->
    db.query sql['delete-feature'], id: req.body.id
      .then send(res)

  app.post "/polygon/delete", (req, res)->
    db.query sql['delete-feature'], id: req.body.id
      .then send(res)

  erase = (req, res)->
    # Erase features given a geojson polygon
    # Returns a list of replaced features
    f = req.body
    geometry = parseGeometry f

    # We can only erase a single type for now
    db.query sql["erase-features"], {geometry}
      .map serializeFeature
      .tap console.log
      .then send(res)

  app.post "/line/erase", erase
  app.post "/polygon/erase", erase

  getTypes = (req, res)->
    # Right now we only have a concept of types that maps
    # directly to layers, with no added data provided.
    Promise.resolve [{id: 'default', name: opts.table, color: '#ff0000'}]
      .then send(res)


  app.get "/line/types", getTypes
  app.get "/polygon/types", getTypes

  return app

