// Generated by CoffeeScript 2.3.0
var Resolver, path, relative, resolveMain, scopedRE;

relative = require('@cush/relative');

path = require('path');

scopedRE = /^((?:@[a-z._-]+\/)?[a-z._-]+)(?:\/(.+))?$/;

Resolver = function(bundle, resolved) {
  var exts, missed, resolveImport, target;
  ({target, exts, missed} = bundle);
  resolveImport = async function(parent, ref) {
    var deps, file, id, match, pack;
    ({file, pack} = parent);
    // ./ or ../
    if (ref[0] === '.') {
      id = relative(file.name, ref);
      if (id === null) {
        cush.emit('warning', {
          message: 'Unsupported import path: ' + ref,
          parent: bundle.relative(parent)
        });
        return false;
      }
      if (!id && !(id = resolveMain(pack))) {
        cush.emit('warning', {
          message: '"main" path is invalid: ' + pack.path,
          package: pack.path
        });
        return false;
      }
    } else if (!path.isAbsolute(ref)) {
      if (match = scopedRE.exec(ref)) {
        deps = pack.data.dependencies;
        if (!deps || !deps[match[1]]) {
          return false;
        }
        if (!(pack = pack.require(match[1]))) {
          return false;
        }
        if (!(id = match[2] || resolveMain(pack))) {
          cush.emit('warning', {
            message: '"main" path is invalid: ' + pack.path,
            package: pack.path
          });
          return false; // absolute paths are forbidden 💥
        }
      }
    } else {
      cush.emit('warning', {
        message: 'Import path must be relative',
        parent: bundle.relative(parent)
      });
      return false;
    }
    await pack.crawl();
    if (file = pack.search(id, target, exts)) {
      return bundle._getModule(file, pack);
    } else {
      return false;
    }
  };
  // Resolve all dependencies of a module.
  return function(parent) {
    var modules;
    modules = {};
    return parent.deps.forEach(async function(dep, i) {
      var mod;
      mod = dep.module;
      if (!mod || !mod.file.id) {
        if (!(mod = modules[dep.ref])) {
          modules[dep.ref] = mod = resolveImport(parent, dep.ref);
          resolved.push(mod);
        }
        if (mod = (await mod)) {
          dep.module = mod;
          return;
        }
        // The module cannot be found.
        missed.push([parent, i]);
        return;
      }
      if (!modules[dep.ref]) {
        modules[dep.ref] = mod;
        resolved.push(mod);
      }
    });
  };
};

module.exports = Resolver;

// Resolve the main module of a package.
resolveMain = function(pack) {
  var id;
  if (id = pack.data.main) {
    if (id[0] === '.') {
      return relative('', id);
    } else {
      return id;
    }
  } else {
    return 'index';
  }
};