import "regenerator-runtime/runtime.js";
const { serial: test } = require("ava");
import database, { buildQueryCache } from "./database";
import { argParser } from "./arg-parser";

const db = database({
  connection: process.env.MAPBOARD_TEST_DB,
});
const sql = buildQueryCache({ schema: "map_digitizer" });

test("insert using stored procedure", async (t) => {
  const s1 = sql["new-line"];
  const res = await db.one(s1, {
    schema: "map_digitizer",
    snap_width: 0,
    snap_types: [],
    type: "default",
    pixel_width: null,
    map_width: null,
    certainty: null,
    zoom_level: null,
    geometry: "LINESTRING(16.1 -24.3,16.2 -24.4)",
  });
  t.is(res["type"], "default");
  t.pass();
});
