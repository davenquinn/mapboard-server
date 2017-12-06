# Map Digitizer Server

A server component that interfaces with the Map-Digitizer app, an in-development iPad client for
digitizing mapping data.

This allows you to store your data in a PostGIS database and edit it with a slick digitizing stylus.

## Setup

1. Run `yarn` in the root directory to get the requisite node modules
2. Run the `create-tables` command.
3. Run the server with the `run-server` command.

## Compiling

The server can be compiled to a single executable CLI using `pkg`. Make sure that
`coffee` and `pkg` are installed globally.
