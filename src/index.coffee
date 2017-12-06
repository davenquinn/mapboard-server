args = require './arg-parser'
appFactory = require './feature-server'

app = appFactory args

server = app.listen args.port, ->
  console.log "Listening on port #{server.address().port}"
