import "regenerator-runtime/runtime.js";
import { createServer as createServerBase } from "http";
import { featureServer } from "./feature-server";
import { topologyWatcher } from "./topology-watcher";

function appFactory(opts) {
  const app = featureServer(opts);
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
