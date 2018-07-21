{evalFile, extRegex, getCallSite, getModule, uhoh} = require '../utils'
{loadBundle, dropBundle} = require '../workers'
isObject = require 'is-object'
Emitter = require '@cush/events'
Package = require './Package'
Module = require 'module'
Asset = require './Asset'
build = require './build'
cush = require 'cush'
path = require 'path'
log = require('lodge').debug('cush')
fs = require 'saxon/sync'

empty = []
nodeModulesRE = /\/node_modules\//

class Bundle extends Emitter
  @Asset: Asset
  @Package: Package

  constructor: (opts) ->
    super()
    @id = opts.id
    @dev = Boolean opts.dev
    @root = null
    @main = null
    @target = opts.target
    @assets = []
    @packages = Object.create null
    @plugins = opts.plugins or []
    @parsers = opts.parsers or []
    @project = null
    @valid = false
    @state = null
    @time = 0
    @_result = null
    @_loading = null
    @_loadedPlugins = new Set
    @_nextAssetId = 1
    @_workers = []
    @_config = null
    @_events = null
    @_extRE = null
    @_init = opts.init

  relative: (filename) ->
    filename.slice @root.path.length + 1

  resolve: (relativePath) ->
    path.resolve @root.path, relativePath

  read: ->
    @_result or= @_build()

  use: (plugins) ->
    if !Array.isArray plugins
      plugins = [plugins]

    Promise.all plugins.map (val) =>
      if Array.isArray val
        return @use val

      plugin =
        if typeof val is 'string'
        then await resolvePlugin val, @main.path()
        else val

      return if !plugin or @_loadedPlugins.has plugin
      @_loadedPlugins.add plugin

      if typeof val is 'string'
        plugin.id = val

      if plugin.worker?
        if typeof plugin.worker is 'string'
        then @worker plugin.worker
        else log.warn '`worker` must be a file path: %O', plugin

      if typeof plugin.default is 'function'
        plugin = plugin.default

      if typeof plugin is 'function'
        try await plugin.call this
        catch err
          log.error err
          return

  worker: (val) ->

    if typeof val is 'function'
      frame = getCallSite(1)
      @_workers.push
        func: val.toString()
        path: frame.getFileName()
        line: frame.getLineNumber()
      return

    if typeof val isnt 'string'
      throw TypeError "`worker` must be passed a filename or function"

    if !path.isAbsolute val
      val = path.resolve path.dirname(getCallSite(1).getFileName()), val

    @_workers.push path: val
    return

  getSourceMapURL: (value) ->
    '\n\n' + @_wrapSourceMapURL \
      typeof value is 'string' and
      value + '.map' or
      value.toUrl()

  unload: ->
    @_unload()
    @_result = null
    return

  destroy: ->
    @_result = Promise.resolve null

    @main = null
    @assets = null

    @packages.forEach (pack) ->
      pack.watcher?.destroy()
    @packages = null

    @project.drop this
    @project = null

    dropBundle this
    @emitAsync 'destroy'
    return

  _parseExt: (name) ->
    if match = @_extRE.exec name
      return match[0]

  _getInitialConfig: ->
    ctr = @constructor
    exts: ctr.exts?.slice(0) or []

  _onConfigure: ->
    @_extRE = extRegex @get('exts') or empty, @get('known exts') or empty
    return

  _configure: ->
    @_config = @_getInitialConfig()
    @_events = events = {}

    if @_init
      try await @_init()
      catch err
        log.error err

    await @_callPlugins()
    await @project._configure(this)

    if events.config
      events.config.emit()
      events.config = null

    @_onConfigure()
    loadBundle this
    return this

  _callPlugins: ->
    if @plugins.length
      return @use @plugins

  _build: -> try
    @valid = true
    @state = {}

    await @_loading or= @_configure()
    return null if !@valid

    time = process.hrtime()
    bundle = await build this, @state
    return null if !@valid

    time = process.hrtime time
    @state.elapsed = Math.ceil time[0] * 1e3 + time[1] * 1e-6
    return bundle

  catch err
    # Errors are ignored when the next build is automatic.
    if @valid
      @_result = null
      @_invalidate()
      throw err

  # Invalidate the current build, and disable automatic rebuilds
  # until the next build is triggered manually.
  _invalidate: ->
    @valid = false
    @emitAsync 'invalidate'
    return

  # Schedule an automatic rebuild.
  _rebuild: ->
    if @_result
      @_invalidate() if @valid
      @_result = @_result
        .then noEarlier 200 + Date.now()
        .then @_build.bind this
      return

  _unload: ->
    @_invalidate() if @valid

    # Reset the main module.
    @main.content = null
    @main.deps = null

    # Reset the asset cache.
    @assets = [,@main]
    @_nextAssetId = 2

    # Reset the root package.
    @root.crawled = false
    @root.assets = Object.create null
    @root.assets[@main.name] = @main
    @root.users = new Set

    # Reset the package cache.
    @packages = Object.create null
    @packages[@root.data.name] =
      new Map [[@root.data.version, @root]]

    @_loading = null
    @_loadedPlugins.clear()
    return

  _loadAsset: (name, pack) ->
    assetId = @_nextAssetId++
    @assets[assetId] = asset =
      new Asset assetId, name, pack
    pack.assets[name] = asset
    return asset

  _loadPackage: (root, data) ->
    if !path.isAbsolute root
      throw Error "Package root must be absolute: '#{root}'"

    data ?= evalFile path.join(root, 'package.json')

    if !data.name
      throw Error 'Package has no "name" field: ' + root
    if !data.version
      throw Error 'Package has no "version" field: ' + root

    if versions = @packages[data.name]
      return pack if pack = versions.get data.version
    else @packages[data.name] = versions = new Map

    versions.set data.version,
      pack = new Package root, data

    root = fs.follow root, true
    pack._watch root if !nodeModulesRE.test root

    pack.bundle = this
    return pack

  _concat: ->
    throw Error 'Bundle format must override `_concat`'

  _wrapSourceMapURL: ->
    throw Error 'Bundle format must override `_wrapSourceMapURL`'

require('./PluginMixin')(Bundle)
module.exports = Bundle

#
# Helpers
#

# Create a function that enforces a minimum delay.
noEarlier = (time) ->
  return -> new Promise (resolve) ->
    delay = Math.max 0, time - Date.now()
    delay and setTimeout(resolve, delay) or resolve()

resolvePlugin = (name, main) ->
  if name.indexOf('cush-') is -1
    name = 'cush-plugin-' + name
  plugin = tryRequire(name, getModule main)
  plugin or= await lazyRequire name
  plugin

tryRequire = (request, parent) ->
  try filename = Module._resolveFilename(request, parent)
  return parent.require filename if filename
