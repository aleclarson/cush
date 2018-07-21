Module = require 'module'
path = require 'path'
fs = require 'saxon/sync'

evalFile = (file, ext) ->
  if !load = loaders[ext or path.extname file]
    throw Error "Cannot eval '#{file}' without a loader"
  if fs.isFile(file) then load(file) else null

loaders =

  '': fs.read

  '.js': (file) ->
    delete Module._cache[file]
    Module._load file

  '.json': (file) ->
    JSON.parse fs.read file

module.exports = evalFile
