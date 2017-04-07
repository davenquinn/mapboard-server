express = require 'express'
bodyParser = require 'body-parser'
Promise = require 'bluebird'
pgp = require('pg-promise')(promiseLib: Promise)
path = require 'path'

db = pgp "postgres:///Naukluft"

app = express()

app.use bodyParser.json()

sql = (filename)->
  fn = path.join __dirname, filename
  pgp.QueryFile fn, minify: true

getFeatures = sql("sql/get-features-in-area.sql")

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
app.post "/drew-line",(req, res)->
  console.log req.body
  res.send({foo: 'bar'})

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
