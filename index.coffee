express = require 'express'
bodyParser = require 'body-parser'
pgp = require('pg-promise')()
path = require 'path'

db = pgp database: "syrtis"

app = express()

app.use bodyParser.json()

sql = (filename)->
  fn = path.join __dirname, filename
  pgp.QueryFile fn, minify: true

getFeatures = sql("sql/get-features-in-area.sql")

app.post "/features-in-area", (req, res)->
  env = req.body.envelope
  console.log env
  db.query getFeatures, env


  res.send({foo: 'baz'})

# Set up routes
app.post "/drew-line",(req, res)->
  console.log req.body
  res.send({foo: 'bar'})

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
