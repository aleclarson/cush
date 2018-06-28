{concat} = require '../utils'
isObject = require 'is-object'
crawl = require './crawl'
cush = require 'cush'
path = require 'path'

nextFileId = 1

class Package
  constructor: (@path, @data) ->
    @files = Object.create null
    @users = new Set
    @parent = null
    @bundles = new Set
    @exclude = []
    @crawled = false

  crawl: ->
    if not @crawled
      @crawled = true
      crawl @path, @files,
        skip: concat @exclude, cush.config('exclude')

  file: (name) ->
    file = @files[name]
    if file is undefined
      return null

    if typeof file is 'string'
      file = @files[name = file]

    if file is true
      @files[name] = file =
        id: nextFileId++
        name: name
        ext: path.extname name
        content: null
        time: null
        map: null

    return file

  resolve: (file) ->
    path.resolve @path,
      if typeof file is 'string'
      then file
      else file.name

  search: (name, target, exts) ->

    if ext = path.extname name
      # prefer target-specific modules
      pref = name.slice(0, -ext.length) + '.' + target + ext
      return @file(pref) or @file(name)

    # resolve the file extension
    matchFile(name, target, exts, this) or
      # might be a directory name
      matchFile(name + '/index', target, exts, this)

  require: (name) ->
    name = path.join 'node_modules', name
    if pack = @files[name]
      return pack
    if pack = tryPackage path.join @path, name
      pack.parent or= this
      pack.users.add this
      @files[name] = pack
      return pack
    return null

module.exports = Package

#
# Internal
#

# TODO: watch the package.json of 'bad packages'
tryPackage = (root) ->
  try cush.package root
  catch err
    cush.emit 'warning',
      code: 'BAD_PACKAGE'
      message: err.message
      package: root
    return

# Resolve a filename that has no extension.
matchFile = (id, target, exts, pack) ->
  # prefer target-specific modules
  pref = id + '.' + target
  for ext in exts
    file = pack.file(pref + ext) or pack.file(id + ext)
    return file if file
