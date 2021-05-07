import express from "express";
import bodyParser from "body-parser";
import { SQLCache, pgp } from "./database";
import { IDatabase } from "pg-promise";
import wkx from "wkx";
import { Buffer } from "buffer";

//# Support functions ##

function log(d) {
  console.log(d);
}

const schema = process.env.MAPBOARD_SCHEMA || "map_digitizer";

const serializeFeature = function (r) {
  const geometry = Buffer.from(r.geometry, "hex").toString("base64");
  const { id, pixel_width, map_width, certainty } = r;

  const type = r.type != null ? r.type.trim() : null;

  let feature = {
    type: "Feature",
    geometry,
    id,
    properties: {
      type,
      color: r.color.trim(),
      pixel_width,
      map_width,
      certainty,
    },
  };

  // Handle erasing transparently-ish
  // with an extension to the GeoJSON protocol
  if (r.erased == null) {
    r.erased = false;
  }
  if (r.erased) {
    feature = {
      type: "DeletedFeature",
      id: r.id,
    };
  }
  return feature;
};

const parseGeometry = function (f) {
  // Parses a geojson (or wkb, or ewkb) feature to geometry
  //console.log(f.geometry);
  return wkx.Geometry.parse(f.geometry).toEwkb().toString("hex");
};

const send = (res) =>
  function (data) {
    console.log(`${data.length} rows returned\n`.green);
    return res.send(data);
  };

export default function featureServer(
  db: IDatabase<any, any>,
  queryCache: SQLCache,
  opts = {}
) {
  const app = express();
  app.use(bodyParser.json({ limit: "50mb", extended: true }));

  const sql = queryCache;

  const featuresInArea = (table) =>
    function (req, res) {
      const { envelope } = req.body;
      const tables = { table, type_table: table + "_type" };
      if (envelope != null) {
        // Takes care of older cases
        db.query(sql["get-features-in-bbox"], envelope)
          .map(serializeFeature)
          .then(send(res));
        return;
      }
      const geometry = parseGeometry(req.body);
      return db
        .query(sql["get-features-in-polygon"], { geometry, ...tables })
        .map(serializeFeature)
        .then(send(res));
    };

  app.post("/line/features-in-area", featuresInArea("linework"));
  app.post("/polygon/features-in-area", featuresInArea("polygon"));

  app.post("/topology/features-in-area", function (req, res) {
    // This should fail silently or return error if topology doesn't exist
    const geometry = parseGeometry(req.body);
    const tableNames = {
      topo_schema: opts.topology,
      table: "face_display",
    };
    return db
      .query(sql["get-map-faces-in-polygon"], { geometry, ...tableNames })
      .map(serializeFeature)
      .then(send(res));
  });

  // Selection

  const selectFeatures = (table) =>
    async function (req, res) {
      const geometry = parseGeometry(req.body);
      const tables = { table, type_table: table + "_type" };
      return db
        .query(sql["select-features"], {
          geometry,
          ...tables,
          types: null,
        })
        .then(send(res));
    };

  app.post("/line/select-features", selectFeatures("linework"));
  app.post("/polygon/select-features", selectFeatures("polygon"));

  // Set up routes
  app.post("/line/new", async function (req, res) {
    const f = req.body;
    const p = f.properties;
    console.log(p);
    // This should likely be handled better by the backend
    if (p.snap_types == null) {
      p.snap_types = null;
    }
    if (p.snap_width == null) {
      p.snap_width = 2 * map_width;
    }

    /* Topological snapping is broken somehow! */

    if (p.snap_types != null && p.snap_types.length === 1) {
      try {
        const res = await db.one(sql["get-topology"], {
          id: p.snap_types[0],
        });
        console.log(res);
        if (res.topology != null) {
          const vals = await db.query(sql["topology-types"], {
            // We now provide a default value for topology in first-stage mapping, apparently??
            topo: res.topology,
          });
          console.log(vals);
          p.snap_types = vals.map((d) => d.id);
          console.log(`Topological snapping to ${p.snap_types}`);
        }
      } catch (err) {
        console.error(err);
        console.error("Couldn't enable topological snapping");
      }
    }

    const data = {
      geometry: parseGeometry(f),
      ...p,
    };

    console.log(data);
    return db
      .query(sql["new-line"], data)
      .map(serializeFeature)
      .tap(log)
      .then(send(res))
      .catch(console.error);
  });

  app.post("/line/reshape", async function (req, res) {
    const geometry = parseGeometry(req.body);
    let { tolerance, ...rest } = req.body.properties;
    tolerance = tolerance ?? 0;

    return db
      .query(sql["reshape-lines"], { geometry, tolerance, ...rest })
      .map(serializeFeature)
      .tap(log)
      .then(send(res))
      .catch(console.error);
  });

  // Set up routes
  app.post("/polygon/new", async function (req, res) {
    const f = req.body;
    const { properties } = f;
    const geometry = parseGeometry(f);
    let { allow_overlap } = properties;
    if (allow_overlap == null) {
      allow_overlap = false;
    }
    let erased = [];
    if (!allow_overlap) {
      // Null for 'types' erases all types
      erased = await db
        .query(sql["erase-polygons"], { geometry, types: null })
        .map(serializeFeature);
    }

    const data = await db
      .query(sql["new-polygon"], { geometry, ...properties })
      .map(serializeFeature);

    const newRes = data.concat(erased);
    // If we don't want overlap
    return Promise.resolve(newRes).then(send(res)).catch(console.error);
  });

  const deleteFeatures = (table) =>
    function (req, res) {
      const { features } = req.body;
      return db
        .query(sql["delete-features"], { table, features })
        .then(send(res));
    };

  const changeType = (table) =>
    function (req, res) {
      const { features, type } = req.body;
      return db
        .query(sql["change-type"], { features, type, table })
        .then(send(res));
    };

  const modify = (table) =>
    function (req, res) {
      // an open modification route for objects
      const { features, ...vals } = req.body;
      const whereClause = pgp.as.format(`
      WHERE id IN (\${features:csv})
      RETURNING id`);
      const sql =
        pgp.helpers.update(vals, null, { table, schema }) + whereClause;

      return db.query(sql, { features }).then(send(res));
    };

  app.post("/line/delete", deleteFeatures("linework"));
  app.post("/polygon/delete", deleteFeatures("polygon"));

  app.post("/line/change-type", changeType("linework"));
  app.post("/polygon/change-type", changeType("polygon"));

  app.post("/line/modify", modify("linework"));
  app.post("/polygon/modify", modify("polygon"));

  const erase = (procName) =>
    function (req, res) {
      // Erase features given a geojson polygon
      // Returns a list of replaced features
      const f = req.body;
      const geometry = parseGeometry(f);
      const { erase_types } = f.properties;
      const types = erase_types || null;

      return db
        .query(sql[`erase-${procName}`], { geometry, types })
        .map(serializeFeature)
        .tap(log)
        .then(send(res));
    };

  app.post("/line/erase", erase("lines"));
  app.post("/line/topo-erase", erase("lines-topological"));
  app.post("/polygon/erase", erase("polygons"));

  // Line-specific tools

  app.post("/line/heal", function (req, res) {
    /* Line healing is not yet supported by the Mapboard GIS app */
    let { features, type, tolerance } = req.body;
    if (tolerance == null) {
      tolerance = 0;
    } // Don't expect tolerance to be supported

    // Should return messages object
    console.log("Healing lines");
    return db
      .query(sql["heal-lines"], { features, type, tolerance })
      .map(serializeFeature)
      .then(send(res));
  });

  app.post("/line/reverse", (req, res) => {
    const { features } = req.body;
    return db
      .query(sql["reverse-lines"], { features })
      .map(serializeFeature)
      .then(send(res));
  });

  const types = (table) => async (req, res) => {
    const data = await db.query(sql["get-feature-types"], {
      table: table + "_type",
    });
    console.log(`${data.length} rows returned\n`.green);
    res.send(
      data.map((d) => ({
        ...d,
        id: d.id.trim(),
        color: d.color?.trim() ?? "#000000",
        name: d.name.trim(),
      }))
    );
  };

  app.get("/line/types", types("linework"));
  app.get("/polygon/types", types("polygon"));

  app.get("/", (req, res) => {
    res.send("Feature server");
  });

  return app;
}
