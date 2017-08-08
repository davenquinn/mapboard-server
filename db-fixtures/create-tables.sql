CREATE SCHEMA map_digitizer;

CREATE TABLE map_digitizer.linework_type (
    id text PRIMARY KEY,
    name text,
    color text,
    bedrock boolean DEFAULT false
);

CREATE TABLE map_digitizer.linework (
  id            serial PRIMARY KEY,
  geometry      public.geometry(MultiLineString,$srid::integer) NOT NULL,
  type          text,
  created       timestamp without time zone DEFAULT now(),
  certainty     integer,
  zoom_level    integer,
  pixel_width   numeric,
  map_width     numeric,
  arbitrary     boolean DEFAULT false,
  source        text,
  name          text,
  FOREIGN KEY (type) REFERENCES map_digitizer.linework_type(id) ON UPDATE CASCADE;
);
CREATE INDEX map_digitizer_linework_geometry_idx ON map_digitizer.linework USING gist (geometry);

CREATE TABLE map_digitizer.polygon_type (
    id text PRIMARY KEY,
    name text,
    color text,
    bedrock boolean DEFAULT false
);

CREATE TABLE map_digitizer.polygon (
  id            serial PRIMARY KEY,
  geometry      public.geometry(MultiPolygon,$srid::integer) NOT NULL,
  type          text,
  created       timestamp without time zone DEFAULT now(),
  certainty     integer,
  zoom_level    integer,
  arbitrary     boolean DEFAULT false,
  source        text,
  name          text,
  FOREIGN KEY (type) REFERENCES map_digitizer.polygon_type(id) ON UPDATE CASCADE;
);
CREATE INDEX map_digitizer_polygon_geometry_idx ON map_digitizer.polygon USING gist (geometry);
