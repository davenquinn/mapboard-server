#!/usr/bin/env node
/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const glob = require("glob");
import database, { pgp } from "./database";

const { QueryFile } = pgp;

async function createFixtures(db, params) {
  let result = [];
  for (const file of glob.sync(`${__dirname}/../db-fixtures/*.sql`)) {
    const sql = new QueryFile(file, { params });
    console.log(file);
    result.push(await db.query(sql));
  }
  return result;
}

async function createTables(argv) {
  const { srid, schema, tiles, topology } = argv;
  const params = {
    schema,
    srid,
    data_schema: schema,
    topo_schema: topology,
    topology,
  };

  const db = database(argv);

  try {
    await db.query("SELECT count(*) FROM ${schema~}.linework", { schema });
    return;
  } catch (error) {
    console.log("Tables not found, creating...");
  }

  try {
    await createFixtures(db, params);
  } catch (error1) {
    console.error(error1);
  }
}

export { createTables };
