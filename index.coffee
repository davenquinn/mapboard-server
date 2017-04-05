express = require 'express'
bodyParser = require 'body-parser'

app = express()

app.use bodyParser.json()

app.post "/features-in-area", (req, res)->
  console.log req.body
  res.send({foo: 'baz'})

# Set up routes
app.post "/drew-line",(req, res)->
  console.log req.body
  res.send({foo: 'bar'})

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
