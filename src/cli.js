require("coffeescript/register");
var argParser = require("./arg-parser");
var appFactory = require("./feature-server");
var morgan = require("morgan");

var args = argParser();
var app = appFactory(args);

if (process.env.NODE_ENV != "production") {
  app.use(morgan("dev"));
}

var server = app.listen(args.port, function () {
  console.log("Listening on port " + server.address().port.toString());
});
