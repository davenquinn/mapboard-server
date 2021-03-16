import "regenerator-runtime/runtime.js";
import express from "express";
import { createServer as createServerBase } from "http";
import featureServer from "./feature-server";
import topologyWatcher from "./topology-watcher";
import tileServer from "./tile-server";
import metaRoute from "./meta";
import database, { buildQueryCache } from "./database";
import html from "url:./socket-log.html";
import { join } from "path";

function appFactory(opts) {
  if (opts.schema == null) {
    opts.schema = "map_digitizer";
  }

  if (opts.topology == null) {
    opts.topology = "map_topology";
  }

  var app = express();

  const db = database(opts);

  const queryDir = join(__dirname, "..", "/sql");
  const queryCache = buildQueryCache(queryDir, opts);

  // This is kind of hare-brained
  app.set("db", db);
  app.set("sql", queryCache);

  app.use("/", featureServer(db, queryCache));
  app.get("/meta", metaRoute(db, queryCache, opts));

  if (opts.tiles != null) {
    console.log("Serving tiles using config".green, opts.tiles);
    app.use("/tiles", tileServer(opts.tiles));
  }

  app.get("/socket-test", (req, res) => {
    res.sendFile(__dirname + html);
  });

  return app;
}

function createServer(app) {
  const server = createServerBase(app);
  // we should pull database creation up a bit
  const db = app.get("db");
  topologyWatcher(db, server);
  return server;
}

export { argParser } from "./arg-parser";
export { appFactory, topologyWatcher, createServer };
