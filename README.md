# Mapboard Server

A server component that interfaces with [Mapboard GIS](https://mapboard-gis.app), an iPad app for digitizing geologic maps.
This extension allows you to store your data in a PostGIS database and slickly edit it with an *Apple Pencil* stylus.

This project contains APIs for driving map editing from within the app. These APIs can also be used as part of
the [PostGIS Geologic Map](https://github.com/davenquinn/PostGIS-Geologic-Map) project (this module is a submodule).
That project also includes processes for iteratively maintaining a topologically valid geologic map.

## Setup

1. Run `yarn` or `npm install` in the root directory to get the requisite node modules
2. Run the `create-tables` command.
3. Run the server with the `run-server` command.

## Compiling

The server can be compiled to a single executable CLI using `pkg`. Make sure that
`coffee` and `pkg` are installed globally.
