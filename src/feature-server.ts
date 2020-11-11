/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const express = require('express');
const bodyParser = require('body-parser');
const Promise = require('bluebird');
const PGPromise = require('pg-promise');
const path = require('path');
const wkx = require('wkx');
const {Buffer} = require('buffer');
const {readdirSync} = require('fs');
const colors = require('colors');
const tileServer = require('./tile-server');

const logFunc = function(e){
  console.log(colors.grey(e.query));
  if (e.params != null) {
    return console.log("    "+colors.cyan(e.params));
  }
};

const connectFunc = function(client, dc, isFresh){
  if (isFresh) {
    return client.on('notice', function(msg){
      const v = `${msg.severity} ${msg.code}: `+msg.where;
      console.log(v);
      return console.log("msg %j",msg);
    });
  }
};

const pgp = PGPromise({promiseLib: Promise, query: logFunc, connect: connectFunc});

//# Support functions ##

const serializeFeature = function(r){
  const geometry = new Buffer(r.geometry,'hex').toString('base64');
  const {id, pixel_width, map_width, certainty} = r;

  let feature = {
    type: 'Feature',
    geometry, id,
    properties: {
      type: r.type.trim(),
      color: r.color.trim(),
      pixel_width,
      map_width,
      certainty
    }
  };

  // Handle erasing transparently-ish
  // with an extension to the GeoJSON protocol
  if (r.erased == null) { r.erased = false; }
  if (r.erased) {
    feature = {
      type: 'DeletedFeature',
      id: r.id
    };
  }
  return feature;
};

const parseGeometry = function(f){
  // Parses a geojson (or wkb, or ewkb) feature to geometry
  console.log(f.geometry);
  return wkx.Geometry.parse(f.geometry).toEwkb().toString("hex");
};

const send = res => (function(data) {
  console.log(`${data.length} rows returned\n`.green);
  return res.send(data);
});

module.exports = function(opts){
  // Can pass in dbname or db object
  let {dbname, schema, tiles, connection} = opts;
  if ((dbname != null) && dbname.startsWith("postgres://")) {
    connection = dbname;
  }

  if ((connection == null)) {
    connection = `postgres:///${dbname}`;
  }
  const db = pgp(connection);

  const app = express();
  app.use(bodyParser.json());

  if (opts.schema == null) { opts.schema = 'map_digitizer'; }

  if (tiles != null) {
    console.log("Serving tiles using config".green, tiles);
    app.use("/tiles", tileServer(tiles));
  }

  //# Prepare SQL queries
  const dn = path.join(__dirname, '..', '/sql');
  const sql = {};
  for (let fn of Array.from(readdirSync(dn))) {
    const key = path.basename(fn,'.sql');
    const _ = path.join(dn,fn);
    sql[key] = pgp.QueryFile(_, {minify: true, debug: true, params: {schema}});
  }

  const featuresInArea = table => (function(req, res) {
    const {envelope} = req.body;
    const tables = {table, type_table: table+'_type'};
    if (envelope != null) {
      // Takes care of older cases
      db.query(sql['get-features-in-bbox'], envelope)
        .map(serializeFeature)
        .then(send(res));
      return;
    }
    const geometry = parseGeometry(req.body);
    return db.query(sql['get-features-in-polygon'], {geometry, ...tables})
      .map(serializeFeature)
      .then(send(res));
  });

  app.post("/line/features-in-area", featuresInArea('linework'));
  app.post("/polygon/features-in-area", featuresInArea('polygon'));

  app.post("/polygon/faces-in-area", function(req, res){
    // This should fail silently or return error if topology doesn't exist
    const geometry = parseGeometry(req.body);
    const tables = {
      topo_schema: "mapping",
      table: "map_face"
    };
    return db.query(sql['get-map-faces-in-polygon'], {geometry, ...tables})
      .map(serializeFeature)
      .then(send(res));
  });

  // Set up routes
  app.post("/line/new",async function(req, res){
    const f = req.body;
    const p = f.properties;
    // This should likely be handled better by the backend
    if (p.snap_types == null) { p.snap_types = null; }
    if (p.snap_width == null) { p.snap_width = 2*map_width; }

    if ((p.snap_types != null) && (p.snap_types.length === 1)) {
      try {
        const {topology} = await db.one(sql['get-topology'], {id: p.snap_types[0]});
        console.log(topology);
        if (topology != null) {
          const vals = await db.query(sql['topology-types'], {topology});
          p.snap_types = vals.map(d => d.id);
          console.log(`Topological snapping to ${p.snap_types}`);
        }
      } catch (err) {
        console.error(err);
        console.error("Couldn't enable topological mapping");
      }
    }

    const data = {
      geometry: parseGeometry(f),
      ...p
    };

    console.log(data);
    return db.query(sql['new-line'], data)
      .map(serializeFeature)
      .tap(console.log)
      .then(send(res))
      .catch(console.error);
  });

  // Set up routes
  app.post("/polygon/new",async function(req, res){
    const f = req.body;
    const {properties} = f;
    const geometry = parseGeometry(f);
    let {allow_overlap} = properties;
    if (allow_overlap == null) { allow_overlap = false; }
    let erased = [];
    if (!allow_overlap) {
      // Null for 'types' erases all types
      erased = await db.query(sql['erase-polygons'], {geometry, types: null})
        .map(serializeFeature);
    }

    const data = await db.query(sql['new-polygon'], {geometry, ...properties})
      .map(serializeFeature);

    const newRes = data.concat(erased);
    // If we don't want overlap
    return Promise.resolve(newRes)
      .then(send(res))
      .catch(console.error);
  });

  const deleteFeatures = table => (function(req, res) {
    const {features} = req.body;
    return db.query(sql['delete-features'], {table, features})
      .then(send(res));
  });

  const changeType = table => (function(req, res) {
    const {features, type} = req.body;
    return db.query(sql['change-type'], {features, type, table})
      .then(send(res));
  });

  app.post("/line/delete", deleteFeatures('linework'));
  app.post("/polygon/delete", deleteFeatures('polygon'));

  app.post("/line/change-type", changeType('linework'));
  app.post("/polygon/change-type", changeType('polygon'));

  const erase = procName => (function(req, res) {
    // Erase features given a geojson polygon
    // Returns a list of replaced features
    const f = req.body;
    const geometry = parseGeometry(f);
    const {erase_types} = f.properties;
    const types = erase_types || null;

    return db.query(sql[`erase-${procName}`], {geometry, types})
      .map(serializeFeature)
      .tap(console.log)
      .then(send(res));
  });

  app.post("/line/erase", erase("lines"));
  app.post("/polygon/erase", erase("polygons"));

  app.post("/line/heal", function(req, res){
    /* Line healing is not yet supported by the Mapboard GIS app */
    let {features, type, tolerance} = req.body;
    if (tolerance == null) { tolerance = 0; } // Don't expect tolerance to be supported
    return db.query(sql['heal-lines'], {features, type, tolerance})
      .map(serializeFeature)
      .then(send(res));
  });

  const types = table => (req, res) => db.query(sql['get-feature-types'], {table: table+'_type'})
    .then(send(res));

  app.get("/line/types", types('linework'));
  app.get("/polygon/types", types('polygon'));

  return app;
};
