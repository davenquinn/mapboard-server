import "regenerator-runtime/runtime.js";
import { serial as test } from "ava";
import database, { buildQueryCache } from "./database";
import { parseGeometry } from "./util";
import { join } from "path";
import { readFileSync } from "fs";
import { Geometry, Polygon } from "wkx";

const db = database({
  connection: process.env.MAPBOARD_TEST_DB,
});

const queryDir = join(__dirname, "..", "/sql");
const opts = {
  schema: process.env.MAPBOARD_SCHEMA || "map_digitizer",
};
const sql = buildQueryCache(queryDir, opts);
const testSQL = buildQueryCache(join(__dirname, "..", "/sql/testing"), {
  ...opts,
  srid: parseInt(process.env.MAPBOARD_SRID),
});

test("create an initial savepoint", async (t) => {
  await db.none("BEGIN");
  t.pass();
});

test("insert using stored procedure", async (t) => {
  const s1 = sql["new-line"];
  const res = await db.one(s1, {
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

let lineReshapeID: number;

test("insert a basic line near the origin", async (t) => {
  const res = await db.one(testSQL["basic-insert"], {
    type: "default",
    table: "linework",
    geometry: "LINESTRING(0 0, 5 0)",
  });
  lineReshapeID = res.id;
  t.is(res["type"], "default");
  t.pass();
});

test("run a reshaping operation", async (t) => {
  const res = await db.one(testSQL["reshape"], {
    type: "default",
    geometry: "LINESTRING(1 0, 1 1, 3 1, 3 0)",
    tolerance: 0,
  });
  console.log(res);
  t.is(res["result"], "MULTILINESTRING((0 0,1 0,1 1,3 1,3 0,5 0))");
});

test("we should get the same result even with longer tails in our blade geometry", async (t) => {
  const res = await db.one(testSQL["reshape"], {
    type: "default",
    geometry: "LINESTRING(1 -1, 1 1, 3 1, 3 -1)",
    tolerance: 0,
  });
  console.log(res);
  t.is(res["result"], "MULTILINESTRING((0 0,1 0,1 1,3 1,3 0,5 0))");
});

test("we should be able to reshape across multiple lines of the same type", async (t) => {
  await db.one(testSQL["basic-insert"], {
    type: "default",
    table: "linework",
    geometry: "LINESTRING(5 0, 10 0)",
  });

  const res = await db.one(testSQL["reshape"], {
    type: "default",
    geometry: "LINESTRING(4 -1, 4 1, 6 1, 6 -1)",
    tolerance: 0,
  });
  console.log(res);
  t.is(res["result"], "MULTILINESTRING((0 0,4 0,4 1,6 1,6 0,10 0))");
});

test("rollback", async (t) => {
  await db.none("ROLLBACK");
  t.pass();
});

test("test healing", async (t) => {
  const healFile = join(__dirname, "..", "test-cases", "heal-1.json");
  const healData = JSON.parse(readFileSync(healFile, "utf-8"));
  t.assert(healData.features.length === 4);

  for (const feature of healData.features) {
    const geometry = Geometry.parseGeoJSON(feature.geometry).toEwkt();
    await db.one(testSQL["basic-insert"], {
      type: "default",
      table: "linework",
      geometry,
    });
  }

  const coordinates = [
    [
      [-1, -1],
      [-1, 1],
      [1, 1],
      [1, -1],
      [-1, -1],
    ],
  ];

  const geometry = Geometry.parseGeoJSON({
    type: "Polygon",
    coordinates,
  }).toEwkt();

  console.log(geometry);

  const features = await db.query(sql["get-features-in-polygon"], {
    geometry,
    schema: "map_digitizer",
    table: "linework",
    type_table: "linework_type",
  });

  console.log(features);

  const res = await db.query(sql["heal-lines"], {
    features,
    type: "default",
    tolerance: 0.1,
  });
});
