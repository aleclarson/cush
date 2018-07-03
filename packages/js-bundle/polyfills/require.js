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
      loaded[id] = module = {exports: {}};
      loader(module, module.exports);
      return module.exports;
    }

    throw Error('Cannot find module: ' + id);
  };
})();
