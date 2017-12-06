appFactory = require 'tessera'
tilelive = require '@mapbox/tilelive'
express = require 'express'
responseTime = require "response-time"
cors = require 'cors'
morgan = require 'morgan'
loader = require "tilelive-modules/loader"
tileliveCache = require "tilelive-cache"

# This tile server is based on the tessera server.js code.

tileServer = (opts)->

  if typeof opts == 'string'
    opts = {"/": opts}

  app = express().disable("x-powered-by")
  if process.env.NODE_ENV != "production"
    app.use(morgan("dev"))

  # Real tessera server caches, we don't.
  tilelive = require("@mapbox/tilelive")

  tilelive = tileliveCache(tilelive, {})

  loader(tilelive, {})

  for prefix, uri of opts
    app.use prefix, responseTime()
    app.use prefix, cors()
    app.use prefix, appFactory(tilelive, uri)

  return app

module.exports = tileServer
