const fs = require('fs');
try {
  fs.symlinkSync('..', 'node_modules/cush');
} catch(e) {}

const cush = require('./lib/index');
module.exports = cush;

require('./lib/bundles');
require('./lib/projects');

cush.formats = {
  js: require('@cush/js-bundle'),
  css: require('@cush/css-bundle'),
};
