#!/usr/bin/env node
/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('pg-promise');
const query = e => console.log(e.query);
const pgp = _({query});

const argParser = require('./src/arg-parser');
const {dbname, srid, schema, tiles} = argParser();

console.log(dbname, srid, schema);

const {QueryFile} = pgp;
const {readFileSync} = require('fs');

let connection = null;
if ((dbname != null) && dbname.startsWith("postgresql://")) {
  connection = dbname;
}

if ((connection == null)) {
  connection = `postgresql:///${dbname}`;
}

const db = pgp(connection);

const params = {schema, srid};
const procedure = QueryFile(`${__dirname}/db-fixtures/create-tables.sql`, {params});

(async function() {
  let err;
  try {
    await db.query("SELECT count(*) FROM ${schema~}.linework", {schema});
    process.exit();
  } catch (error) {
    err = error;
    console.log("Tables not found, creating...");
  }

  try {
    await db.query(procedure);
  } catch (error1) {
    err = error1;
    console.error(err);
  }
  return process.exit();
})();
