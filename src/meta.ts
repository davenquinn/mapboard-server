const { version } = require("../package.json");

async function getTopologyInfo(db, sql, topology) {
  const res = await db.oneOrNone(sql["get-topology-info"], {
    topology,
  });
  if (res == null || Object.keys(res).length == 0) return null;
  return res;
}

export interface MapboardServerOptions {
  schema?: string;
  topology?: string;
  tiles?: any;
  projectBounds?: [number, number, number, number];
  createFunctions?: boolean;
}

export default function metadataRoute(
  db,
  queryCache,
  opts: MapboardServerOptions
) {
  const sql = queryCache;
  return async function (req, res) {
    const projection = await db.one(sql["get-spatial-ref"]);
    const topology = await getTopologyInfo(db, sql, opts.topology);

    const { projectBounds = null } = opts;

    res.send({
      app: "mapboard-server",
      version,
      projection,
      topology,
      backend: "PostGIS",
      projectBounds,
      capabilities: [
        "basic-editing", // Tools defined in version 1 of the app
        "reshape",
        "topology", // This should only be on if available
        "select-features",
        // This likewise may need to be removed if topology is not available
        "topological-line-erase",
      ],
    });
  };
}
