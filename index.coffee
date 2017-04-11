express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
pgp = require('pg-promise')(promiseLib: Promise)
path = require 'path'
wkx = require 'wkx'

db = pgp "postgres:///Naukluft"

app = express()

app.use bodyParser.json()

sql = (filename)->
  fn = path.join __dirname, filename
  pgp.QueryFile fn, minify: true

getFeatures = sql("sql/get-features-in-area.sql")
newLine = sql("sql/new-line.sql")

app.post "/features-in-area", (req, res)->
  env = req.body.envelope
  db.query getFeatures, env
    .map (r)-> {
      type: 'Feature'
      geometry: JSON.parse(r.geom)
      properties: {type: r.type}
      id: r.id }
    .then (data)->res.send(data)

# Set up routes
app.post "/new-line",(req, res)->
  geom = wkx.Geometry.parseGeoJSON(req.body.geometry).toEwkb()

  db.query newLine, { geometry:geom, lineType: 'contact'}
    .then console.log

  res.send({foo: 'bar'})

app.post "/delete", (req, res)->

app.post "/erase-area", (req, res)->

app.post "/get-types", (req, res)->


server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
