CREATE SCHEMA ${schema~};

CREATE TABLE ${schema~}.linework_type (
    id text PRIMARY KEY,
    name text,
    color text,
    bedrock boolean DEFAULT false
);

CREATE TABLE ${schema~}.linework (
  id            serial PRIMARY KEY,
  geometry      public.geometry(MultiLineString,${srid}) NOT NULL,
  type          text,
  created       timestamp without time zone DEFAULT now(),
  certainty     integer,
  zoom_level    integer,
  pixel_width   numeric,
  map_width     numeric,
  hidden        boolean DEFAULT false,
  source        text,
  name          text,
  FOREIGN KEY (type) REFERENCES ${schema~}.linework_type(id) ON UPDATE CASCADE
);
CREATE INDEX ${schema^}_linework_geometry_idx ON ${schema~}.linework USING gist (geometry);

CREATE TABLE ${schema~}.polygon_type (
    id text PRIMARY KEY,
    name text,
    color text,
    bedrock boolean DEFAULT false
);

CREATE TABLE ${schema~}.polygon (
  id            serial PRIMARY KEY,
  geometry      public.geometry(MultiPolygon,${srid}) NOT NULL,
  type          text,
  created       timestamp without time zone DEFAULT now(),
  certainty     integer,
  zoom_level    integer,
  hidden        boolean DEFAULT false,
  source        text,
  name          text,
  FOREIGN KEY (type) REFERENCES ${schema~}.polygon_type(id) ON UPDATE CASCADE
);
CREATE INDEX ${schema^}_polygon_geometry_idx ON ${schema~}.polygon USING gist (geometry);
