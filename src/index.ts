import "regenerator-runtime/runtime.js";
import express from "express";
import { createServer as createServerBase } from "http";
import { featureServer } from "./feature-server";
import { topologyWatcher } from "./topology-watcher";
import html from "url:./socket-log.html";

function appFactory(opts) {
  const features = featureServer(opts);

  var app = express();

  // This is kind of hare-brained
  app.set("db", features.get("db"));

  app.use("/", features);

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
