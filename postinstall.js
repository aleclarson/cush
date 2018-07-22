const fs = require('fs');

try {
  // allow require("cush") from inside cush
  fs.symlinkSync('..', 'node_modules/cush');
} catch(e) {}

try {
  // allow require("cush/utils")
  fs.symlinkSync('./lib/utils', 'utils');
} catch(e) {}
