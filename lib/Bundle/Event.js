// Generated by CoffeeScript 2.3.0
var BundleEvent, log;

log = require('lodge').debug('cush');

BundleEvent = class BundleEvent {
  constructor() {
    this.hooks = [];
    this._next = 0;
  }

  add(hook, priority = 0) {
    if (priority === 1) {
      this.hooks.push(hook);
    } else {
      if (priority === 0) {
        this.hooks.splice(this._next, 0, hook);
      } else {
        this.hooks.unshift(hook);
      }
      this._next += 1;
    }
    return hook;
  }

  emit(...args) {
    return this.hooks.forEach(function(hook) {
      var err;
      try {
        return hook(...args);
      } catch (error) {
        err = error;
        return log.error(err);
      }
    });
  }

};

module.exports = BundleEvent;