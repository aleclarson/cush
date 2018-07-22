// Generated by CoffeeScript 2.3.0
var Asset, loadAsset, path;

({loadAsset} = require('../workers'));

path = require('path');

Asset = class Asset {
  constructor(id, name, owner) {
    this.id = id;
    this.name = name;
    this.owner = owner;
    this.content = null;
    this.deps = null;
    this.map = null;
    this.time = 0;
  }

  path() {
    return path.join(this.owner.path, this.name);
  }

  async _load() {
    return Object.assign(this, (await loadAsset(this)));
  }

  _unload() {
    if (this.content !== null) {
      this.content = null;
      this.map = null;
    }
  }

};

module.exports = Asset;