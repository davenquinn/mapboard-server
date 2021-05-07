import yargs from "yargs";

function argParser() {
  const cli = yargs
    .scriptName("mapboard")
    .usage(
      'mapboard [--schema "schema"] [--topology "topology"] [--srid 4326 ] dbname'
    )
    .option("srid", {
      describe: `SRID for database features \
(computed automatically except for at table creation).`,
      type: "integer",
      default: 4326,
    })
    .option("schema", {
      describe: "Schema for tables",
      type: "string",
      default: process.env.MAPBOARD_SCHEMA ?? "map_digitizer",
    })
    .help("h")
    .alias("h", "help")
    .option("topology", {
      describe: "Topology to use",
      type: "string",
      default: process.env.MAPBOARD_TOPOLOGY ?? "map_topology",
    });

  return cli;
}

export { argParser };
