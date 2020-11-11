/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const argParser = require('./arg-parser');
const appFactory = require('./feature-server');

const args = argParser();
const app = appFactory(args);

var server = app.listen(args.port, () => console.log("Listening on port "+server.address().port.toString()));

