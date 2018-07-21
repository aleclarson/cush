// Generated by CoffeeScript 2.3.0
var Package, crawl, cush, deleteValue, dropPackage, each, evalFile, findPackage, ignored, isObject, localPathRE, matchLocals, nodeModulesExpr, noop, path, wch;

({crawl, each, evalFile, findPackage, ignored, noop} = require('../utils'));

({dropPackage} = require('../workers'));

isObject = require('is-object');

cush = require('cush');

path = require('path');

wch = require('wch');

nodeModulesExpr = wch.expr({
  only: ['/node_modules/*/package.json', '/node_modules/@*/*/package.json'],
  type: 'f'
});

Package = class Package {
  constructor(path1, data) {
    this.path = path1;
    this.data = data;
    this.main = null;
    this.assets = Object.create(null);
    this.users = new Set;
    this.owner = null;
    this.bundle = null;
    this.worker = null;
    this.missedAsset = false;
    this.missedPackage = false;
    this.crawled = false;
    this.watcher = null;
    this.skip = [];
    matchLocals(data.dependencies, this.skip);
    matchLocals(data.devDependencies, this.skip);
  }

  relative(absolutePath) {
    return absolutePath.slice(this.path.length + 1);
  }

  resolve(relativePath) {
    return path.resolve(this.path, relativePath);
  }

  crawl() {
    this.crawled || (this.crawled = (() => {
      crawl(this.path, this.assets, {
        skip: ignored(this.skip)
      });
      return true;
    })());
    return this;
  }

  search(name, target, exts) {
    var asset, ext, i, j, len, len1, nameAndTarget;
    if (ext = this.bundle._parseExt(name)) {
      asset = this._loadAsset(name.slice(0, 1 - ext.length) + target + ext);
      return asset || this._loadAsset(name);
    }
    // try without an extension
    if (asset = this._loadAsset(name)) {
      return asset;
    }
    // maybe an implicit extension?
    nameAndTarget = name + '.' + target;
    for (i = 0, len = exts.length; i < len; i++) {
      ext = exts[i];
      if (asset = this._loadAsset(nameAndTarget + ext) || this._loadAsset(name + ext)) {
        return asset;
      }
    }
    // maybe a directory?
    name += '/index';
    nameAndTarget = name + '.' + target;
    for (j = 0, len1 = exts.length; j < len1; j++) {
      ext = exts[j];
      if (asset = this._loadAsset(nameAndTarget + ext) || this._loadAsset(name + ext)) {
        return asset;
      }
    }
    // not found
    return null;
  }

  require(ref) {
    var name;
    if (name = this._getRequireName(ref)) {
      return this._require(name, ref);
    } else {
      return null;
    }
  }

  _getRequireName(ref) {
    var dep, ref1;
    if (dep = (ref1 = this.data.dependencies) != null ? ref1[ref] : void 0) {
      if (dep.startsWith('file:')) {
        dep = path.relative('', dep.slice(5));
        if (dep[0] === '.') {
          return null;
        } else {
          return dep;
        }
      } else {
        return path.join('node_modules', ref);
      }
    } else {
      return null;
    }
  }

  _require(name, ref) {
    var err, pack;
    if (pack = this.assets[name]) {
      return pack;
    }
    try {
      pack = this.bundle._loadPackage(this.resolve(name));
    } catch (error) {
      err = error;
      if (err.code === 'NOT_PACKAGE') {
        if (!(pack = this._lookup(ref))) {
          return null;
        }
      } else {
        cush.emit('warning', {
          code: 'BAD_PACKAGE',
          message: err.message,
          package: this.resolve(name)
        });
        return null;
      }
    }
    this.assets[name] = pack;
    pack.owner || (pack.owner = this);
    pack.users.add(this);
    return pack;
  }

  // Look for a dependency in an ancestor.
  _lookup(ref) {
    var data, name, pack, root;
    if (this === this.bundle.root) {
      return null;
    }
    root = findPackage(this.path);
    data = evalFile(path.join(root, 'package.json'));
    pack = this.bundle.packages[data.name].get(data.version);
    // Check `data.dependencies` for the expected location.
    if (name = pack._getRequireName(ref)) {
      return pack._require(name, ref);
    }
    // NPM may hoist packages to a parent that has multiple children
    // that use a package that the parent does *not* use directly.
    name = path.join('node_modules', ref);
    if (fs.exists(path.join(root, name))) {
      return pack._require(name, ref);
    }
    // Try the next ancestor.
    return pack._lookup(ref);
  }

  _loadAsset(name) {
    var asset;
    asset = this.assets[name];
    if (typeof asset === 'string') {
      asset = this.assets[name = asset];
    }
    if (asset) {
      if (asset === true) {
        return this.bundle._loadAsset(name, this);
      }
      return asset;
    }
    return null;
  }

  // Returns false if "package.json" has a new name/version or does not exist.
  _read() {
    var data, err, name, version;
    ({name, version} = this.data);
    try {
      data = evalFile(this.resolve('package.json'));
      if ((name === data.name) && (version === data.version)) {
        if (this.missedPackage) {
          this.bundle._rebuild();
        }
        this.data = data;
        return true;
      }
      return false;
    } catch (error) {
      err = error;
      // Be forgiving about malformed JSON.
      if (err.name === 'SyntaxError') {
        return true;
      }
      throw err;
    }
  }

  // Packages within a "node_modules" directory cannot be watched.
  _watch(root = this.path) {
    var moduleExpr, stream;
    moduleExpr = wch.expr({
      skip: ignored(this.skip)
    });
    stream = wch.stream(root, {
      expr: ['anyof', nodeModulesExpr, moduleExpr],
      fields: ['name', 'exists', 'new'],
      since: 1 + Math.ceil(Date.now() / 1000)
    });
    stream.on('data', (evt) => {
      var asset;
      if (evt.name === '/') {
        return;
      }
      if (/^node_modules\//.test(evt.name)) {
        // Skip new packages.
        if (evt.new) {
          if (this.missedPackage) {
            this.bundle._rebuild();
          }
          return;
        }
        // Skip unused packages.
        evt.name = path.dirname(evt.name);
        if (!(asset = this.assets[evt.name])) {
          return;
        }
        // Skip packages with unchanged name/version.
        if (evt.exists && dep._read()) {
          return;
        }
        // Unload the package if we own it.
        if (this === dep.owner) {
          return dep._unload();
        }
      } else {
        evt.pack = this;
        this.bundle.emitAsync('change', evt);
        if (evt.new) {
          this.assets[evt.name] = true;
          if (this.missedAsset) {
            this.bundle._rebuild();
          }
          return;
        }
        if (this.owner === null && evt.name === 'package.json') {
          // Packages without a parent must reload their own data.
          this._read();
        }
        asset = this.assets[evt.name];
        if (isObject(asset)) {
          this.bundle._rebuild();
          if (asset === this.main) {
            this.main = null;
          }
          if (evt.exists) {
            asset.time = Date.now();
            return asset._unload();
          }
          // Mark the asset as deleted.
          asset.id = null;
        // Keep modified assets in memory.
        } else if (evt.exists) {
          return;
        }
      }
      // Remove deleted assets and stale packages.
      return delete this.assets[evt.name];
    });
    stream.on('error', (err) => {
      return cush.emit('error', {
        message: 'An error occurred on a watch stream',
        error: err,
        root: root,
        pack: this
      });
    });
    this.watcher = stream;
    return this;
  }

  _unload() {
    var now, ref1, versions;
    this._unload = noop;
    // Update the times of our assets,
    // and unlink our dependencies.
    now = Date.now();
    each(this.assets, (asset) => {
      if (!isObject(asset)) {
        return;
      }
      if (asset.name) {
        delete this.bundle.assets[asset.id];
        asset.id = null; // mark as deleted
        return;
      }
      // The asset is a package.
      asset.users.delete(this);
      if (this === asset.owner) {
        asset._unload();
      }
    });
    // Destroy the asset cache.
    this.assets = null;
    // Update our dependent packages.
    this.users.forEach((user) => {
      var name;
      name = user._getRequireName(this.data.name);
      if (user.assets[name]) {
        return delete user.assets[name];
      } else {
        return deleteValue(user.assets, this);
      }
    });
    // Remove from the package cache.
    versions = this.bundle.packages[this.data.name];
    versions.delete(this.data.version);
    if (versions.size === 0) {
      delete this.bundle.packages[this.data.name];
    }
    // Stop watching.
    if ((ref1 = this.watcher) != null) {
      ref1.destroy();
    }
    // Notify workers.
    dropPackage(this);
  }

};

module.exports = Package;


// Helpers

localPathRE = /^file:(?:\.\/)?(.+)/;

matchLocals = function(deps, locals) {
  var dep, match;
  if (deps) {
    for (dep in deps) {
      if (match = localPathRE.exec(dep)) {
        locals.push(match[1] + '/**');
      }
    }
  }
};

deleteValue = function(obj, val) {
  var key;
  for (key in obj) {
    if (obj[key] === val) {
      delete obj[key];
      return;
    }
  }
};