express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
PGPromise = require 'pg-promise'
path = require 'path'
wkx = require 'wkx'
{Buffer} = require 'buffer'
{readdirSync} = require 'fs'
colors = require 'colors'
tileServer = require './tile-server'

logFunc = (e)->
  console.log colors.grey(e.query)
  if e.params?
    console.log "    "+colors.cyan(e.params)

connectFunc = (client, dc, isFresh)->
  if isFresh
    client.on 'notice', (msg)->
      v = "#{msg.severity} #{msg.code}: "+msg.where
      console.log(v)
      console.log("msg %j",msg)

pgp = PGPromise(promiseLib: Promise, query: logFunc, connect: connectFunc)

## Support functions ##

serializeFeature = (r)->
  geometry = new Buffer(r.geometry,'hex').toString 'base64'
  {id, pixel_width, map_width, certainty} = r

  feature = {
    type: 'Feature'
    geometry, id
    properties: {
      type: r.type.trim()
      color: r.color.trim()
      pixel_width
      map_width
      certainty
    }
  }

  # Handle erasing transparently-ish
  # with an extension to the GeoJSON protocol
  r.erased ?= false
  if r.erased
    feature =
      type: 'DeletedFeature'
      id: r.id
  return feature

parseGeometry = (f)->
  # Parses a geojson (or wkb, or ewkb) feature to geometry
  console.log f.geometry
  wkx.Geometry.parse(f.geometry).toEwkb().toString("hex")

send = (res)->
  (data)->
    console.log "#{data.length} rows returned\n".green
    res.send(data)

module.exports = (opts)->
  # Can pass in dbname or db object
  {dbname, schema, tiles, db} = opts
  if not db?
    db = pgp "postgres:///#{dbname}"

  app = express()
  app.use bodyParser.json()

  opts.schema ?= 'map_digitizer'

  if tiles?
    console.log "Serving tiles using config".green, tiles
    app.use "/tiles", tileServer(tiles)

  ## Prepare SQL queries
  dn = path.join __dirname, '..', '/sql'
  sql = {}
  for fn in readdirSync(dn)
    key = path.basename(fn,'.sql')
    _ = path.join(dn,fn)
    sql[key] = pgp.QueryFile _, minify: true, debug: true, params: {schema}

  db.query sql['snap-function']
    .then -> console.log "SQL functions are set up!!!".green

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

    if p.snap_types? and p.snap_types.length == 1
      try
        {topology} = await db.one sql['get-topology'], {id: p.snap_types[0]}
        console.log topology
        if topology?
          vals = await db.query sql['topology-types'], {topology}
          p.snap_types = vals.map (d)->d.id
          console.log "Topological snapping to #{p.snap_types}"
      catch err
        console.error err
        console.error "Couldn't enable topological mapping"

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

