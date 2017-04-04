http = require 'http'


console.log "Listening for API requests"

requestListener = (req, res)->
  res.writeHead 200
  res.end 'Hello, World!\n'
  console.log "Request made with content", req.content

server = http.createServer(requestListener)
server.listen(3006)
