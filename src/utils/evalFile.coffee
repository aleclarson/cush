Module = require 'module'
path = require 'path'
fs = require 'saxon/sync'

evalFile = (file) ->
  return load file if load = loaders[path.extname file]
  throw Error "Cannot eval '#{file}' without a loader"

loaders =

  '.js': (file) ->
    delete Module._cache[file]
    Module._load file

  '.json': (file) ->
    JSON.parse fs.read file

module.exports = evalFile
