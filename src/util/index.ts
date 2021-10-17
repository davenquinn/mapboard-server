import wkx from "wkx";
import { Buffer } from "buffer";

interface FeatureInfo {
  type: "Feature" | "DeletedFeature";
  id: number;
  geometry?: object | string;
  properties?: object;
}

export function serializeGeometry(geometry) {
  return Buffer.from(geometry, "hex").toString("base64");
}

export function serializeFeature(r): FeatureInfo {
  const geometry = serializeGeometry(r.geometry);
  const { id, pixel_width, map_width, certainty } = r;

  const type = r.type != null ? r.type.trim() : null;

  let feature: FeatureInfo = {
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
}

export function parseGeometry(f): string {
  // Parses a geojson (or wkb, or ewkb) feature to geometry
  //console.log(f.geometry);
  return wkx.Geometry.parse(f.geometry).toEwkb().toString("hex");
}
