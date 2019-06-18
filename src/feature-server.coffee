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

pgp = PGPromise({promiseLib: Promise, query: logFunc, connect: connectFunc})

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
  {dbname, schema, tiles, connection} = opts
  if not connection?
    connection = "postgres:///#{dbname}"
  db = pgp(connection)

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

  featuresInArea = (table)->(req, res)->
    {envelope} = req.body
    tables = {table, type_table: table+'_type'}
    if envelope?
      # Takes care of older cases
      db.query sql['get-features-in-bbox'], envelope
        .map serializeFeature
        .then send(res)
      return
    geometry = parseGeometry(req.body)
    db.query sql['get-features-in-polygon'], {geometry, tables...}
      .map serializeFeature
      .then send(res)

  app.post "/line/features-in-area", featuresInArea('linework')
  app.post "/polygon/features-in-area", featuresInArea('polygon')

  app.post "/polygon/faces-in-area", (req, res)->
    # This should fail silently or return error if topology doesn't exist
    geometry = parseGeometry(req.body)
    tables = {
      topo_schema: "mapping"
      table: "map_face"
    }
    db.query sql['get-map-faces-in-polygon'], {geometry, tables...}
      .map serializeFeature
      .then send(res)

  # Set up routes
  app.post "/line/new",(req, res)->
    f = req.body
    p = f.properties
    # This should likely be handled better by the backend
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
      .catch console.error

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
      .catch console.error

  deleteFeatures = (table)->(req, res)->
    {features} = req.body
    db.query sql['delete-features'], {table, features}
      .then send(res)

  changeType = (table)->(req, res)->
    {features, type} = req.body
    db.query sql['change-type'], {features, type, table}
      .then send(res)

  app.post "/line/delete", deleteFeatures('linework')
  app.post "/polygon/delete", deleteFeatures('polygon')

  app.post "/line/change-type", changeType('linework')
  app.post "/polygon/change-type", changeType('polygon')

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

  app.post "/line/heal", (req, res)->
    {features, type, tolerance} = req.body
    tolerance ?= 0 # Don't expect tolerance to be supported
    db.query sql['heal-lines'], {features, type, tolerance}
      .map serializeFeature
      .then send(res)

  types = (table)->(req, res)->
    db.query sql['get-feature-types'], {table: table+'_type'}
      .then send(res)

  app.get "/line/types", types('linework')
  app.get "/polygon/types", types('polygon')

  return app
