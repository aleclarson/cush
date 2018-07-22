{each, evalFile, extRegex, getCallSite, getModule, uhoh} = require '../utils'
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
resolved = Promise.resolve null
nodeModulesRE = /\/node_modules\//

jsParser = require.resolve '../parsers/js'
cssParser = require.resolve '../parsers/css'

INIT = 1  # never built before
LAZY = 2  # no automatic rebuilds
IDLE = 3  # waiting for changes
REDO = 4  # scheduled to rebuild
BUSY = 5  # build in progress
DONE = 6  # build complete

class Bundle extends Emitter
  @Asset: Asset
  @Package: Package
  @Status: {INIT, LAZY, IDLE, REDO, BUSY, DONE}

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
    @project = null
    @status = INIT
    @state = null
    @time = 0
    @_extRE = null
    @_config = null
    @_events = null
    @_workers = []
    @_loading = null
    @_loadedPlugins = new Set
    @_nextAssetId = 1
    @_result = null

  relative: (absolutePath) ->
    absolutePath.slice @root.path.length + 1

  resolve: (relativePath) ->
    path.resolve @root.path, relativePath

  read: ->
    if @status <= IDLE
      if @_result is null
      then @_result = @_build()
      else @_result = @_result.then @_build.bind this
    else @_result

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

  worker: (arg) ->

    if typeof arg is 'function'
      frame = getCallSite(1)
      @_workers.push
        func: arg.toString()
        path: frame.getFileName()
        line: frame.getLineNumber()
      return

    if typeof arg isnt 'string'
      throw TypeError '`worker` must be passed a filename or function'

    if !path.isAbsolute arg
      arg = path.resolve path.dirname(getCallSite(1).getFileName()), arg

    @_workers.push path: arg
    return

  getSourceMapURL: (arg) ->
    '\n\n' + @_wrapSourceMapURL \
      typeof arg is 'string' and
      arg + '.map' or
      arg.toUrl()

  unload: ->
    @status = LAZY
    if @status > IDLE
    then @_result.then @_unload.bind this
    else @_unload()
    return

  destroy: ->
    @emitAsync 'destroy'

    @project.drop this
    @project = null

    @unload()
    @_result = resolved
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

    # Add the built-in parsers.
    @merge 'parsers', [jsParser, cssParser]

    # Call format-provided plugins.
    if @constructor.plugins
      await @use @constructor.plugins

    # Call plugins provided during creation.
    if @plugins.length
      await @use @plugins

    # Apply `cush.config.js` configuration.
    await @project._configure(this)

    if events.config
      events.config.emit()
      events.config = null

    @_onConfigure()
    loadBundle this
    return this

  _build: ->
    if @status isnt INIT
      @emitSync 'rebuild'

    @state = {}
    @status = BUSY
    try
      await @_loading or= @_configure()
      return null if @status isnt BUSY

      time = Date.now()
      bundle = await build this, @state
      return null if @status isnt BUSY

      @time = time
      @status = DONE
      return bundle

    catch err
      return null if @status isnt BUSY

      @status = LAZY
      @_result = resolved
      throw err

  # Schedule an automatic rebuild.
  _invalidate: (reload) ->
    if @status > REDO or @status == IDLE
      @status = REDO
      @emitAsync 'invalidate'
      @_result = @_result
        .then noEarlier Date.now() + 100
        .then =>
          @_unload() if reload
          @_build()
      return

  _unload: ->
    dropBundle this

    # Reset the main module.
    @main.content = null
    @main.deps = null

    # Clear the asset cache.
    @assets = [, @main]
    @_nextAssetId = 2

    # Reset the root package.
    @root.crawled = false
    @root.assets = Object.create null
    @root.assets[@main.name] = @main
    @root.users = new Set

    # Unwatch all packages (except the project root).
    each @packages, (pack) =>
      if pack isnt @root
        pack.watcher?.destroy()
      return

    # Clear the package cache.
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

    if !data or= evalFile path.join(root, 'package.json')
      uhoh 'Missing package.json', 'NOT_PACKAGE'
    if !data.name
      uhoh 'Package has no "name" field', 'NO_NAME'
    if !data.version
      uhoh 'Package has no "version" field', 'NO_VERSION'

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
  return -> wait time - Date.now()

wait = (ms) -> new Promise (resolve) ->
  if ms > 0 then setTimeout(resolve, ms) else resolve()

resolvePlugin = (name, main) ->
  if name.indexOf('cush-') is -1
    name = 'cush-plugin-' + name
  plugin = tryRequire(name, getModule main)
  plugin or= await lazyRequire name
  plugin

tryRequire = (request, parent) ->
  try filename = Module._resolveFilename(request, parent)
  return parent.require filename if filename
