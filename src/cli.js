require("coffeescript/register");
var argsParser = require('./arg-parser');
var appFactory = require('./feature-server');

var args = argParser();
var app = appFactory(args);

var server = app.listen(args.port,function(){
  console.log ("Listening on port "+server.address().port.toString());
});

