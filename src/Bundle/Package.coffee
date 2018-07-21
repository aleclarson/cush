{crawl, each, evalFile, findPackage, ignored, noop} = require '../utils'
{dropPackage} = require '../workers'
isObject = require 'is-object'
cush = require 'cush'
path = require 'path'
wch = require 'wch'

nodeModulesExpr = wch.expr
  only: ['/node_modules/*/package.json', '/node_modules/@*/*/package.json']
  type: 'f'

class Package
  constructor: (@path, data) ->
    @data = data
    @main = null
    @assets = Object.create null
    @users = new Set
    @owner = null
    @bundle = null
    @worker = null
    @missedAsset = false
    @missedPackage = false
    @crawled = false
    @watcher = null
    @skip = []
    matchLocals data.dependencies, @skip
    matchLocals data.devDependencies, @skip

  relative: (absolutePath) ->
    absolutePath.slice @path.length + 1

  crawl: ->
    @crawled or= do =>
      crawl @path, @assets,
        skip: ignored @skip
      return true
    return this

  resolve: (asset) ->
    if typeof asset isnt 'string'
      asset = asset.name
    path.resolve @path, asset

  search: (name, target, exts) ->

    if ext = @bundle._parseExt name
      asset = @_loadAsset(name.slice(0, 1 - ext.length) + target + ext)
      return asset or @_loadAsset(name)

    # try without an extension
    if asset = @_loadAsset name
      return asset

    # maybe an implicit extension?
    nameAndTarget = name + '.' + target
    for ext in exts
      if asset = @_loadAsset(nameAndTarget + ext) or @_loadAsset(name + ext)
        return asset

    # maybe a directory?
    name += '/index'
    nameAndTarget = name + '.' + target
    for ext in exts
      if asset = @_loadAsset(nameAndTarget + ext) or @_loadAsset(name + ext)
        return asset

    # not found
    return null

  require: (ref) ->
    if name = @_getRequireName ref
    then @_require name, ref
    else null

  _getRequireName: (ref) ->
    if dep = @data.dependencies?[ref]
      if dep.startsWith 'file:'
        dep = path.relative '', dep.slice(5)
        if dep[0] is '.' then null else dep
      else path.join 'node_modules', ref
    else null

  _require: (name, ref) ->
    if pack = @assets[name]
      return pack

    try pack = @bundle._loadPackage path.join(@path, name)
    catch err

      if err.code is 'NOT_PACKAGE'
        if !pack = @_lookup ref
          return null

      else
        cush.emit 'warning',
          code: 'BAD_PACKAGE'
          message: err.message
          package: path.join(@path, name)
        return null

    @assets[name] = pack
    pack.owner or= this
    pack.users.add this
    return pack

  # Look for a dependency in an ancestor.
  _lookup: (ref) ->
    if this is @bundle.root
      return null

    root = findPackage @path
    data = evalFile path.join(root, 'package.json')
    pack = @bundle.packages[data.name].get data.version

    # Check `data.dependencies` for the expected location.
    if name = pack._getRequireName ref
      return pack._require name, ref

    # NPM may hoist packages to a parent that has multiple children
    # that use a package that the parent does *not* use directly.
    name = path.join 'node_modules', ref
    if fs.exists path.join(root, name)
      return pack._require name, ref

    # Try the next ancestor.
    return pack._lookup ref

  _loadAsset: (name) ->
    asset = @assets[name]
    if typeof asset is 'string'
      asset = @assets[name = asset]
    if asset
      if asset == true
        return @bundle._loadAsset name, this
      return asset
    return null

  # Returns false if "package.json" has a new name/version or does not exist.
  _read: ->
    {name, version} = @data
    try
      data = evalFile path.join(@path, 'package.json')
      if (name is data.name) and (version is data.version)
        @bundle._rebuild() if @missedPackage
        @data = data
        return true
      return false
    catch err
      # Be forgiving about malformed JSON.
      if err.name is 'SyntaxError'
        return true
      throw err

  # Packages within a "node_modules" directory cannot be watched.
  _watch: (root = @path) ->

    moduleExpr = wch.expr
      skip: ignored @skip

    stream = wch.stream root,
      expr: ['anyof', nodeModulesExpr, moduleExpr]
      fields: ['name', 'exists', 'new']
      since: 1 + Math.ceil Date.now() / 1000

    stream.on 'data', (evt) =>
      return if evt.name is '/'

      if /^node_modules\//.test evt.name
        # Skip new packages.
        if evt.new
          @bundle._rebuild() if @missedPackage
          return

        # Skip unused packages.
        evt.name = path.dirname evt.name
        return if !asset = @assets[evt.name]

        # Skip packages with unchanged name/version.
        return if evt.exists and dep._read()

        # Unload the package if we own it.
        if this is dep.owner
          return dep._unload()

      else
        evt.pack = this
        @bundle.emitAsync 'change', evt

        if evt.new
          @assets[evt.name] = true
          @bundle._rebuild() if @missedAsset
          return

        # Packages without a parent must reload their own data.
        @_read() if @owner is null and evt.name is 'package.json'

        asset = @assets[evt.name]
        if isObject asset
          @bundle._rebuild()

          if asset is @main
            @main = null

          if evt.exists
            asset.time = Date.now()
            return asset._unload()

          # Mark the asset as deleted.
          asset.id = null

        # Keep modified assets in memory.
        else if evt.exists
          return

      # Remove deleted assets and stale packages.
      delete @assets[evt.name]

    stream.on 'error', (err) =>
      cush.emit 'error',
        message: 'An error occurred on a watch stream'
        error: err
        root: root
        pack: this

    @watcher = stream
    return this

  _unload: ->
    @_unload = noop

    # Update the times of our assets,
    # and unlink our dependencies.
    now = Date.now()
    each @assets, (asset) =>
      return if !isObject asset

      if asset.name
        delete @bundle.assets[asset.id]
        asset.id = null  # mark as deleted
        return

      # The asset is a package.
      asset.users.delete this
      if this is asset.owner
        asset._unload()
        return

    # Destroy the asset cache.
    @assets = null

    # Update our dependent packages.
    name = path.join 'node_modules', @data.name
    @users.forEach (user) =>
      if user.assets[name]
        delete user.assets[name]
      else deleteValue user.assets, this

    # Remove from the package cache.
    versions = @bundle.packages[@data.name]
    versions.delete @data.version
    if versions.size is 0
      delete @bundle.packages[@data.name]

    # Stop watching.
    @watcher?.destroy()

    # Notify workers.
    dropPackage this
    return

module.exports = Package

#
# Helpers
#

localPathRE = /^file:(?:\.\/)?(.+)/

matchLocals = (deps, locals) ->
  if deps then for dep of deps
    if match = localPathRE.exec dep
      locals.push match[1] + '/**'
  return

deleteValue = (obj, val) ->
  for key of obj
    if obj[key] is val
      delete obj[key]
      return
