import express from "express";
import bodyParser from "body-parser";
import { SQLCache } from "./database";
import { IDatabase } from "pg-promise";
import wkx from "wkx";
import { Buffer } from "buffer";

//# Support functions ##

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
  console.log(f.geometry);
  return wkx.Geometry.parse(f.geometry).toEwkb().toString("hex");
};

const send = (res) =>
  function (data) {
    console.log(`${data.length} rows returned\n`.green);
    return res.send(data);
  };

export default function featureServer(
  db: IDatabase<any, any>,
  queryCache: SQLCache
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
      topo_schema: "map_topology",
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
      console.log(req);
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
    // This should likely be handled better by the backend
    if (p.snap_types == null) {
      p.snap_types = null;
    }
    if (p.snap_width == null) {
      p.snap_width = 2 * map_width;
    }

    if (p.snap_types != null && p.snap_types.length === 1) {
      try {
        const { topology } = await db.one(sql["get-topology"], {
          id: p.snap_types[0],
        });
        if (topology != null) {
          const vals = await db.query(sql["topology-types"], { topology });
          p.snap_types = vals.map((d) => d.id);
          console.log(`Topological snapping to ${p.snap_types}`);
        }
      } catch (err) {
        console.error(err);
        console.error("Couldn't enable topological mapping");
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
      .tap(console.log)
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

  app.post("/line/delete", deleteFeatures("linework"));
  app.post("/polygon/delete", deleteFeatures("polygon"));

  app.post("/line/change-type", changeType("linework"));
  app.post("/polygon/change-type", changeType("polygon"));

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
        .tap(console.log)
        .then(send(res));
    };

  app.post("/line/erase", erase("lines"));
  app.post("/polygon/erase", erase("polygons"));

  app.post("/line/heal", function (req, res) {
    /* Line healing is not yet supported by the Mapboard GIS app */
    let { features, type, tolerance } = req.body;
    if (tolerance == null) {
      tolerance = 0;
    } // Don't expect tolerance to be supported
    return db
      .query(sql["heal-lines"], { features, type, tolerance })
      .map(serializeFeature)
      .then(send(res));
  });

  const types = (table) => (req, res) =>
    db
      .query(sql["get-feature-types"], { table: table + "_type" })
      .then(send(res));

  app.get("/line/types", types("linework"));
  app.get("/polygon/types", types("polygon"));

  app.get("/", (req, res) => {
    res.send("Feature server");
  });

  return app;
}
