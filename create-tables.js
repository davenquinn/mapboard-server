#!/usr/bin/env node
/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require("pg-promise");
const query = (e) => console.log(e.query);
const pgp = _({ query });

const { argParser } = require("../dist");
const { dbname, srid, schema, tiles } = argParser();

console.log(dbname, srid, schema);

const { QueryFile } = pgp;
const { readFileSync } = require("fs");

let connection = null;
if (dbname != null && dbname.startsWith("postgresql://")) {
  connection = dbname;
}

if (connection == null) {
  connection = `postgresql:///${dbname}`;
}

const db = pgp(connection);

const params = { schema, srid };

async function createFixtures() {
  let result = [];
  for (let file of Array.from(glob.sync(`${__dirname}/db-fixtures/*.sql`))) {
    const sql = QueryFile(file, { params });
    result.push(await db.query(sql));
  }
  return result;
}

(async function () {
  let err;
  try {
    await db.query("SELECT count(*) FROM ${schema~}.linework", { schema });
    process.exit();
  } catch (error) {
    err = error;
    console.log("Tables not found, creating...");
  }

  try {
    await createFixtures();
  } catch (error1) {
    err = error1;
    console.error(err);
  }
  return process.exit();
})();
