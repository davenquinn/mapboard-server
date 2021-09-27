import { argParser } from "./arg-parser";
import { createTables } from "./create-tables";
import { readFileSync } from "fs";

const appFactory = require("./feature-server");
const morgan = require("morgan");

function ensureDatabase(argv) {
  if (argv.db_conn == null) {
    console.error("Must specify a database name or connection");
    process.exit();
  }
  return argv;
}

const createTablesCommand = {
  command: "create-tables [db_conn]",
  describe: "Create default tables",
  async handler(argv) {
    await createTables(ensureDatabase(argv));
  },
};

const serveCommand = {
  command: "serve [db_conn]",
  describe: "Serve",
  builder(yargs) {
    yargs
      .option("port", {
        describe: "Port on which to serve",
        type: "integer",
        default: 3006,
      })
      .option("tiles", {
        describe: `A tilelive config URL (or JSON file) \
to define a tile source. All URLs will \
be rewritten and mounted at tiles/`,
        type: "string",
      });
  },
  async handler(argv) {
    let { tiles } = argv;

    if (tiles != null && tiles.endsWith(".json")) {
      // Parse tile config if it's a JSON file
      tiles = JSON.parse(readFileSync(tiles, "utf-8"));
    }

    const app = appFactory(ensureDatabase({ ...argv, tiles }));

    if (process.env.NODE_ENV != "production") {
      app.use(morgan("dev"));
    }

    var server = app.listen(argv.port, () =>
      console.log("Listening on port " + server.address().port.toString())
    );
  },
};

const cli = argParser()
  .command(serveCommand)
  .command(createTablesCommand)
  .demandCommand()
  .help();

cli.argv;
