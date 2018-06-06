(function() {
  var loaders = [], loaded = [];
  window.__d = function __d(id, loader) {
    loaders[id] = loader;
  };
  window.require = function require(id) {
    var module = loaded[id];
    if (module) return module.exports;

    var loader = loaders[id];
    if (loader) {
      var exports = {};
      factory(module = {exports}, exports);
      loaded[id] = module;
      return module.exports;
    }

    throw Error('Cannot find module: ' + id);
  };
})();
