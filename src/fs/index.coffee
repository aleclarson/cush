{concat, each, evalFile, findPackage} = require '../utils'
isObject = require 'is-object'
Package = require './Package'
cush = require 'cush'
noop = require 'noop'
path = require 'path'
wch = require 'wch'
fs = require 'saxon/sync'

# Packages by [name].get(version)
cush.packages = packages = Object.create null

# Get/load package by absolute path
cush.package = (root, data) ->
  if !path.isAbsolute root
    throw Error "Package root must be absolute: '#{root}'"

  data ?= evalFile path.join(root, 'package.json')

  if !data.name
    throw Error 'Package has no "name" field: ' + root
  if !data.version
    throw Error 'Package has no "version" field: ' + root

  if versions = packages[data.name]
    return pack if pack = versions.get data.version
  else packages[data.name] = versions = new Map

  versions.set data.version,
    pack = new Package root, data

  # Avoid crawling/watching local packages.
  each data.dependencies, excludeLocals, pack
  each data.devDependencies, excludeLocals, pack

  # Any package whose "real" path is in a
  # 'node_modules' directory is *not* watched.
  root = fs.follow root, true
  if !nodeModulesRE.test root
    watchPackage pack, root

  return pack

#
# Internal
#

streams = new Map

nodeModulesRE = /^node_modules\//
nodeModulesExpr = wch.expr
  only: ['/node_modules/*', '/node_modules/@*/*']
  type: 'dl'

excludeLocals = (dep) ->
  if dep.indexOf('file:./') is 0
    @exclude.push dep.slice(7) + '/**'
  return

watchPackage = (pack, root) ->
  skip = concat pack.exclude, cush.config('exclude')

  stream = wch.stream root,
    expr: ['anyof', nodeModulesExpr, wch.expr {skip}]
    fields: ['name', 'exists', 'new']
    since: 1 + Math.ceil Date.now() / 1000

  stream.on 'data', (file) ->

    if file.name is '/'
      pack.bundles.clear()
      return pack._purge()

    if !nodeModulesRE.test file.name
      file.pack = pack
      process.nextTick cush.emit, 'change', file

      if file.new
        pack.files[file.name] = true
        return

      if file.exists
        unloadFile pack.files[file.name], pack
        readPackage pack if file.name is 'package.json'
        return

    # Remove old files and packages.
    delete pack.files[file.name]

  stream.on 'error', (err) ->
    err.root = root
    err.pack = pack
    cush.emit 'error', err

  streams.set pack, stream
  return

# Reset the file's content, and rebuild bundles that use it.
unloadFile = (file, pack) ->
  if isObject(file) and file.content isnt null
    content = fs.read path.join(pack.root, file.name)
    if content isnt file.content
      file.ext = path.extname file.name
      file.content = content
      file.time = Date.now()
      file.map = null

      # Only changed files trigger rebuilds.
      pack.bundles.forEach (bundle) ->
        bundle._unloadModule file.id

readPackage = (pack) ->
  {name, version} = pack.data
  try data = evalFile file.path
  catch e then return

  # Purge packages with new name/version.
  if (name isnt data.name) or (version isnt data.version)
    return pack._purge()

# Reset the package cache (for testing).
Object.defineProperty cush, '_resetPackages', value: ->
  cush.packages = packages = Object.create null
  streams.forEach (s) -> s.destroy()
  streams.clear()
  return

# Remove a package from the cache, and stop watching it.
Package::_purge = ->
  @_purge = noop
  versions = packages[@data.name]
  versions.delete @data.version
  if versions.size is 0
    delete packages[@data.name]
  if stream = streams.get this
    streams.delete this
    stream.destroy()
  return
