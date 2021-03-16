const argParser = require("./arg-parser");
const appFactory = require("./feature-server");
const morgan = require("morgan");

const args = argParser();
const app = appFactory(args);

if (process.env.NODE_ENV != "production") {
  app.use(morgan("dev"));
}

var server = app.listen(args.port, () =>
  console.log("Listening on port " + server.address().port.toString())
);
