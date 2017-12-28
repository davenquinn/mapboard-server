require("coffeescript/register");
var args = require('./arg-parser');
var appFactory = require('./feature-server');

var app = appFactory(args);

var server = app.listen(args.port,function(){
  console.log ("Listening on port "+server.address().port.toString());
});

