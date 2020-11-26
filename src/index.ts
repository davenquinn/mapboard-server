import "regenerator-runtime/runtime.js";
import express from "express";
import { createServer as createServerBase } from "http";
import featureServer from "./feature-server";
import topologyWatcher from "./topology-watcher";
import tileServer from "./tile-server";
import metaRoutes from "./meta";
import database from "./database";
import html from "url:./socket-log.html";

function appFactory(opts) {
  if (opts.schema == null) {
    opts.schema = "map_digitizer";
  }

  var app = express();

  const db = database(opts);
  // This is kind of hare-brained
  app.set("db", db);

  app.use("/", featureServer(db, opts));
  metaRoutes(app);

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
