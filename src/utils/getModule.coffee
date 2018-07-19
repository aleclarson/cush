Module = require 'module'
path = require 'path'

getModule = (filename) ->
  if !mod = Module._cache[filename]
    mod = new Module '', null
    mod.filename = filename
    mod.paths = Module._nodeModulePaths path.dirname(filename)
    mod.loaded = true
  return mod

module.exports = getModule
