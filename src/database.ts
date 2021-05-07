import Bluebird from "bluebird";
import PGPromise from "pg-promise";
import colors from "colors";
import path from "path";
import { readdirSync } from "fs";

const QUIET = true;

const logFunc = function (event) {
  if (QUIET) return;
  console.log(colors.grey(event.query));
  if (event.params != null) {
    console.log("    " + colors.cyan(event.params));
  }
};

const connectFunc = function (client, dc, isFresh) {
  if (isFresh) {
    return client.on("notice", function (msg) {
      const v = `${msg.severity} ${msg.code}: ` + msg.where;
      console.log(v);
      console.log("msg %j", msg);
    });
  }
};

export const pgp = PGPromise({
  capSQL: true,
  promiseLib: Bluebird,
  query: logFunc,
  //connect: connectFunc,
});

export type SQLCache = {
  [key: string]: PGPromise.QueryFile;
};

export function buildQueryCache(directory, params): SQLCache {
  //# Prepare SQL queries
  const sql = {};
  for (let fn of Array.from(readdirSync(directory))) {
    const key = path.basename(fn, ".sql");
    const _ = path.join(directory, fn);
    sql[key] = new pgp.QueryFile(_, {
      minify: true,
      debug: true,
      params,
    });
  }
  return sql;
}

export default function database(opts) {
  // Can pass in dbname or db object
  let { db_conn, connection } = opts;
  db_conn = db_conn ?? connection;
  if (
    !(db_conn.startsWith("postgres://") || db_conn.startsWith("postgresql://"))
  ) {
    db_conn = "postgres://" + db_conn;
  }
  return pgp(db_conn);
}

export const { QueryFile } = pgp;
