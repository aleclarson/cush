{getty} = require 'getty'
Module = require 'module'
path = require 'path'
cush = require 'cush'
fs = require 'fsx'

class File
  constructor: (name, pack) ->
    @name = name
    @pack = pack
    @data = null
    @imports = null

  read: ->
    if @data is null
      @data = fs.readFile @path
      @ast = @parse() if @parse
    return @data

  dirty: ->
    @data = null
    @ast = null if @parse

    cush.emit 'file:change', this
    return

  eval: (ext) ->
    return load this if load = loaders[ext or @ext]
    throw Error "Cannot eval '#{@path}' without a loader"

getty File,
  ext: -> path.extname @name
  path: -> path.join @pack.path, @name

module.exports = File

# File loaders
loaders =

  '.js': (file) ->
    delete Module._cache[file.path]
    Module._load file.path

  '.json': (file) ->
    JSON.parse file.data or fs.readFile file.path
