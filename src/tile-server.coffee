appFactory = require 'tessera'
tilelive = require '@mapbox/tilelive'
express = require 'express'
responseTime = require "response-time"
cors = require 'cors'
morgan = require 'morgan'
loader = require "tilelive-modules/loader"
tileliveCache = require "tilelive-cache"

# have to require mbtiles to make sure it is consumed by loader
# when we have packaged the server
require '@mapbox/mbtiles'

# This tile server is based on the tessera server.js code.

tileServer = (opts)->

  if typeof opts == 'string'
    opts = {"/": opts}

  app = express().disable("x-powered-by")
  if process.env.NODE_ENV != "production"
    app.use(morgan("dev"))

  # Real tessera server caches, we don't.
  tilelive = require("@mapbox/tilelive")
  tilelive = tileliveCache(tilelive)

  loader(tilelive, {})

  for prefix, uri of opts
    app.use prefix, responseTime()
    app.use prefix, cors()
    # Uses `davenquinn/tessera`
    # so we don't have to load mapnik native modules
    # to run the tile server on weird architectures
    app.use prefix, appFactory(tilelive, uri)

  return app

module.exports = tileServer
