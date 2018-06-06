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
  only: ['/node_modules/*/package.json', '/node_modules/@*/*/package.json']
  type: 'f'

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

  stream.on 'data', (evt) ->
    return if evt.name is '/'

    if nodeModulesRE.test evt.name
      # Skip new packages.
      return if evt.new

      # Skip unused packages.
      evt.name = path.dirname evt.name
      return if !dep = pack.files[evt.name]

      # Skip packages with unchanged name/version.
      return if evt.exists and readPackage dep

      # Unload the package if we own it.
      if pack is dep.parent
        return dep._unload()

    else
      evt.pack = pack
      process.nextTick cush.emit, 'change', evt

      if evt.new
        pack.files[evt.name] = true
        return

      # Packages without a parent must reload their own data.
      if !pack.parent and evt.name is 'package.json'
        readPackage pack

      file = pack.files[evt.name]
      if isObject file

        # Rebuild bundles that use this file.
        pack.bundles.forEach (bundle) ->
          bundle._unloadModule file.id

        if evt.exists
          return unloadFile file

        # Mark the file as deleted.
        file.id = 0

      # Keep modified files in memory.
      else if evt.exists
        return

    # Remove deleted files and stale packages.
    delete pack.files[evt.name]

  stream.on 'error', (err) ->
    err.root = root
    err.pack = pack
    cush.emit 'error', err

  streams.set pack, stream
  return

# Unload the file's content.
unloadFile = (file) ->
  if file.content isnt null
    file.ext = path.extname file.name
    file.content = null
    file.time = Date.now()
    file.map = null
  return

# Returns false if "package.json" has a new name/version or does not exist.
readPackage = (pack) ->
  {name, version} = pack.data
  try
    data = evalFile path.join(pack.root, 'package.json')
    if (name is data.name) and (version is data.version)
      pack.data = data
      return true
    return false

  catch err
    # Be forgiving about malformed JSON.
    return err.name is 'SyntaxError'

# Reset the package cache (for testing).
Object.defineProperty cush, '_resetPackages', value: ->
  cush.packages = packages = Object.create null
  streams.forEach (s) -> s.destroy()
  streams.clear()
  return

# Remove a package from the cache, and stop watching it.
Package::_unload = ->
  @_unload = noop

  # Update the times of our files,
  # and unlink our dependencies.
  now = Date.now()
  for name, file of @files
    continue if !isObject file

    if file.name
      file.time = now
      continue

    file.users.delete this
    if this is file.parent
      file._unload()

  # Destroy the file cache.
  @files = null

  # Update our dependent packages.
  name = path.join 'node_modules', @data.name
  @users.forEach (user) ->
    delete user.files[name]

  # Invalidate any bundles.
  if @bundles.size
    @bundles.forEach (bundle) ->
      bundle.valid = false  # Disable automatic rebuilds (temporarily).
      bundle._result = null
      return

  # Remove from the package cache.
  versions = packages[@data.name]
  versions.delete @data.version
  if versions.size is 0
    delete packages[@data.name]

  # Stop watching.
  if stream = streams.get this
    streams.delete this
    stream.destroy()
  return
