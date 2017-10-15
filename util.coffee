{Geometry} = require 'wkx'
{Buffer} = require 'buffer'

serializeFeature = (r)->
  geometry = new Buffer(r.geometry,'hex').toString 'base64'
  {id, map_width} = r

  map_width ?= 1

  feature = {
    type: 'Feature'
    geometry, id
    properties: {
      type: 'default'
      color: "#ff0000"
      pixel_width: 5
      map_width
      certainty: null
    }
  }

  # Handle erasing transparently-ish
  # with an extension to the GeoJSON protocol
  r.erased ?= false
  if r.erased
    feature =
      type: 'DeletedFeature'
      id: r.id
  return feature

parseGeometry = (f)->
  # Parses a geojson (or wkb, or ewkb) feature to geometry
  console.log f.geometry
  Geometry.parse(f.geometry).toEwkb().toString("hex")

send = (res)->
  (data)->
    console.log "#{data.length} rows returned\n".green
    res.send(data)

module.exports = {serializeFeature, parseGeometry, send}

