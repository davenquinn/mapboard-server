app = require './feature-server'

server = app.listen 3006, ->
  console.log "Listening on port #{server.address().port}"
