const fs = require('fs');
try {
  fs.symlinkSync('..', 'node_modules/cush');
} catch(e) {}

const cush = require('./lib/index');
module.exports = cush;

require('./lib/fs');
require('./lib/bundles');
require('./lib/projects');
require('./lib/registry');

// Bundle formats
cush.formats = [
  require('js-bundle'),
  require('css-bundle'),
];
