import Bluebird from "bluebird";
import PGPromise from "pg-promise";
import colors from "colors";
import path from "path";
import { readdirSync } from "fs";

const logFunc = function (e) {
  console.log(colors.grey(e.query));
  if (e.params != null) {
    return console.log("    " + colors.cyan(e.params));
  }
};

const connectFunc = function (client, dc, isFresh) {
  if (isFresh) {
    return client.on("notice", function (msg) {
      const v = `${msg.severity} ${msg.code}: ` + msg.where;
      console.log(v);
      return console.log("msg %j", msg);
    });
  }
};

const pgp = PGPromise({
  promiseLib: Bluebird,
  query: logFunc,
  connect: connectFunc,
});

type SQLCache = {
  [key: string]: PGPromise.QueryFile;
};

export function buildQueryCache(opts): SQLCache {
  //# Prepare SQL queries
  const dn = path.join(__dirname, "..", "/sql");
  const sql = {};
  for (let fn of Array.from(readdirSync(dn))) {
    const key = path.basename(fn, ".sql");
    const _ = path.join(dn, fn);
    sql[key] = new pgp.QueryFile(_, {
      minify: true,
      debug: true,
      params: { schema: opts.schema },
    });
  }
  return sql;
}

export default function database(opts) {
  // Can pass in dbname or db object
  let { dbname, connection } = opts;
  if (dbname != null && dbname.startsWith("postgres://")) {
    connection = dbname;
  }
  if (connection == null) {
    connection = `postgres:///${dbname}`;
  }
  return pgp(connection);
}

export const { QueryFile } = pgp;
