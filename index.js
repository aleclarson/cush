const cush = require('./js/index');

// Ensure cush can require itself.
// const fs = require('fsx');
// fs.writeLink(__dirname + '/node_modules/cush', __dirname);
require.cache[__filename] = cush;

cush.bundle = require('./js/Bundle').create;
cush.packages = new (require('./js/PackageCache'));
cush.plugin = require('./js/Plugin').run;

// Bundle types
require('./packages/js-bundle');
require('./packages/css-bundle');

module.exports = cush;
