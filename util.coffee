{Geometry} = require 'wkx'
{Buffer} = require 'buffer'

serializeFeature = (r)->
  geometry = new Buffer(r.geometry,'hex').toString 'base64'
  {id, pixel_width, map_width, certainty} = r

  feature = {
    type: 'Feature'
    geometry, id
    properties: {
      type: r.type.trim()
      color: r.color.trim()
      pixel_width: 5
      map_width: 5
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

