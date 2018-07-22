const cush = require('./lib/index');
module.exports = cush;

require('./lib/bundles');
require('./lib/projects');

cush.formats = {
  js: require('@cush/js-bundle'),
  css: require('@cush/css-bundle'),
};
