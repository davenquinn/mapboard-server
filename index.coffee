express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
pgp = require('pg-promise')(promiseLib: Promise)
path = require 'path'
wkx = require 'wkx'
{readdirSync} = require 'fs'

db = pgp "postgres:///Naukluft"

app = express()

app.use bodyParser.json()

## Prepare SQL queries
dn = path.join __dirname,'sql'
sql = {}
for fn in readdirSync(dn)
  key = path.basename(fn,'.sql')
  _ = path.join(dn,fn)
  sql[key] = pgp.QueryFile _, minify: true

db.query sql['snap-function']
  .then -> console.log "SQL functions are set up!!!"

serializeFeature = (r)->
  {
    type: 'Feature'
    geometry: JSON.parse(r.geometry)
    properties:
      type: r.type
      color: r.color
    id: r.id
  }

parseGeometry = (f)->
  # Parses a geojson feature to geometry
  wkx.Geometry.parseGeoJSON(f.geometry).toEwkb()

app.post "/features-in-area", (req, res)->
  env = req.body.envelope
  db.query sql['get-features-in-area'], env
    .map serializeFeature
    .then (data)->res.send(data)

# Set up routes
app.post "/new-line",(req, res)->
  f = req.body
  data =
    geometry: parseGeometry(f)
    type: f.properties.type
    pixel_width: f.properties.pixel_width
    map_width: f.properties.map_width
    zoom_level: f.properties.zoom_level

  db.one sql['new-line'], data
    .map serializeFeature
    .then (data)->res.send(data)

app.post "/delete", (req, res)->
  db.query sql['delete-line'], id: req.body.id
    .then (data)->res.send(data)

app.post "/erase", (req, res)->
  # Erase features given a geojson polygon
  # Returns a list of replaced features
  f = req.body
  data =
    geometry: parseGeometry(f)
    type: f.properties.type

  db.query sql['erase-lines'], data
    .map serializeFeature
    .then (data)->res.send(data)

app.get "/types", (req, res)->
  db.query sql['get-feature-types']
    .then (data)->res.send(data)

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
