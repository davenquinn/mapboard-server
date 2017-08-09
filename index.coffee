args = require './arg-parser'
appFactory = require './feature-server'

app = appFactory args

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
