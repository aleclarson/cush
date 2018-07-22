snipSyntaxError = require '../utils/snipSyntaxError'
ErrorTracer = require '../utils/ErrorTracer'
mapSources = require '../utils/mapSources'
getModule = require '../utils/getModule'
extRegex = require '../utils/extRegex'
elaps = require 'elaps'
path = require 'path'
log = require('lodge').debug('cush')
fs = require 'saxon'
vm = require 'vm'

empty = []
VERBOSE = process.env.VERBOSE is '1'

elaps.log = log

class Bundle
  constructor: (props) ->
    @id = props.id
    @dev = props.dev
    @root = props.root
    @target = props.target
    @packages = {}
    @_events = {}
    @_config = props.config
    @_extRE = null
    @_timers = {}
    @_resetTimers()
    @_configure props

  relative: (filename) ->
    filename.slice @root.length + 1

  # The "transform" phase occurs after reading the asset.
  transform: (exts, fn) ->

    hook = (asset, pack) =>
      result = fn asset, pack
      if result and result.map
        lap = @_timed('source maps').start()
        mapSources asset, result
        lap.stop()
      return

    hook.source = @_getSource(1)
    if Array.isArray exts
      exts.forEach (ext) => @hook 'asset' + ext, hook
    else @hook 'asset' + exts, hook

  _configure: ({plugins, parsers}) ->

    parsers.forEach (filename) =>
      for ext, parse of require(filename)
        parse.source = {path: filename}
        @hook 'parse' + ext, parse
      return

    for plugin in plugins
      plugin =
        if plugin.func
        then wrapPlugin(plugin).call this
        else require plugin.path
      plugin.call this

    @_extRE = extRegex @get('exts') or empty, @get('known exts') or empty
    return

  _parseExt: (name) ->
    if match = @_extRE.exec name
      return match[0]

  # Run hooks for a module.
  _loadAsset: (name, root) ->
    if !pack = @packages[root]
      lap = @_timed('load packages').start()
      VERBOSE and loadTime = elaps 'load package %O', @relative(root)

      @packages[root] = pack =
        JSON.parse await fs.read path.join(root, 'package.json')
      pack.path = root

      if event = @_events.package
        await Promise.all event.hooks.map (hook) -> hook pack

      VERBOSE and loadTime.stop(true)
      lap.stop()

    if !assetExt = @_parseExt name
      throw Error 'Unknown extension: ' + name

    assetPath = path.join root, name
    VERBOSE and loadTime = elaps 'load asset %O', @relative(assetPath)

    lap = @_timed('read files').start()
    content = await fs.read(assetPath)
    lap.stop()

    lap = @_timed('load assets').start()
    asset =
      ext: assetExt
      path: assetPath
      content: content
      deps: null
      map: null

    try while asset.ext != ext
      ext = asset.ext
      break if !event = @_events['asset' + ext]
      for hook in event.hooks
        VERBOSE and hookTime = @_timedHook(hook).start()
        await hook asset, pack
        VERBOSE and hookTime.stop()
        break if asset.ext != ext

    catch err
      if err.line?
        ErrorTracer(asset)(err, @relative assetPath)
        err.snippet = snipSyntaxError(asset.content, err)
      throw err

    if event = @_events['parse' + ext]
      for hook in event.hooks
        VERBOSE and hookTime = @_timedHook(hook).start()
        await hook asset, pack
        VERBOSE and hookTime.stop()

    if event = @_events['asset']
      for hook in event.hooks
        VERBOSE and hookTime = @_timedHook(hook).start()
        await hook asset, pack
        VERBOSE and hookTime.stop()

    VERBOSE and loadTime.stop(true)
    lap.stop()

    ext: asset.ext
    content: asset.content
    deps: asset.deps
    map: asset.map

  _timed: (id) ->
    @_timers[id] or= elaps.lazy()

  _timedHook: (hook) ->
    @_timers[hook.source.path] or=
      elaps.lazy 'hook %O', path.relative('', hook.source.path)

  _printStats: ->
    if /\bcush\b/.test process.env.DEBUG
      log ''
      log 'worker #' + process.env.WORKER_ID
      @_timed('read files').msg    = 'read %n files in %t'
      @_timed('load assets').msg   = 'loaded %n assets in %t'
      @_timed('load packages').msg = 'loaded %n packages in %t'
      @_timed('source maps').msg   = 'source map tracing took %t'
      timer.print() for id, timer of @_timers

    @_resetTimers()
    return

  _resetTimers: ->
    @_timers =
      'read files': null
      'load assets': null
      'load packages': null
      'source maps': null
    return

require('../Bundle/PluginMixin')(Bundle)
module.exports = Bundle

wrapPlugin = (plugin) ->
  ctx = {}

  if plugin.path
    module = getModule(plugin.path)
    ctx.require = (id) -> module.require id
  else
    ctx.require = require

  script = "function plugin() {return #{plugin.func}}"
  vm.runInNewContext script, ctx,
    filename: plugin.path
    lineOffset: plugin.line
    timeout: 120 * 1000

  return ctx.plugin
