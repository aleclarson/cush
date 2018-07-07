BundleEvent = require './Event'
build = require './build'
noop = require 'noop'
path = require 'path'
cush = require 'cush'

class Bundle
  constructor: (dev, target) ->
    @id = null        # bundle identifier
    @dev = dev        # development mode
    @target = target  # targeted platform
    @root = null      # the root package
    @main = null      # the main module
    @exts = null      # implicit file extensions
    @time = 0         # time of last build
    @valid = false    # not outdated?
    @elapsed = null   # time spent building
    @files = []       # ordered files
    @packages = []    # ordered packages
    @modules = []     # sparse module map
    @missed = []      # missing dependencies
    @_config = null   # plugin config
    @_events = null   # event hooks
    @_format = null   # bundle format
    @_result = null   # build promise

  read: ->
    @_result or= @_build()

  destroy: ->
    @_rev = 0  # cancel the current build
    @read = noop.val Promise.resolve()  # prevent future builds
    @packages.forEach @_dropPackage.bind this  # remove unused packages
    @_project.drop this  # remove unused projects
    return this

  relative: (mod) ->
    throw Error 'Expected a module' if !mod or !mod.pack
    mod.pack.resolve(mod.file).slice @root.path.length + 1

  has: (path) ->
    if typeof path is 'string'
      path = path.split '.'

    obj = @_config
    last = path.length - 1
    for i in [0 ... last]
      obj = obj[path[i]]
      if !obj or typeof obj isnt 'object'
        return false

    return obj[path[last]] isnt undefined

  get: (path) ->
    if typeof path is 'string'
      path = path.split '.'

    obj = @_config
    last = path.length - 1
    for i in [0 ... last]
      obj = obj[path[i]]
      return if !obj?
      if obj.constructor isnt Object
        path = path.slice(0, i + 1).join '.'
        throw TypeError "'#{path}' is not an object"

    return obj[path[last]]

  set: (path, val) ->
    if typeof path is 'string'
      path = path.split '.'

    obj = @_config
    last = path.length - 1
    for i in [0 ... last]
      prev = obj
      obj = prev[path[i]]
      if !obj?
        prev[path[i]] = obj = {}
      else if obj.constructor isnt Object
        path = path.slice(0, i + 1).join '.'
        throw TypeError "'#{path}' is not an object"

    obj[path[last]] = val
    return this

  getSourceMapURL: (value) ->
    '\n\n' + @_wrapSourceMapURL \
      typeof value is 'string' and
      value + '.map' or
      value.toUrl()

  hook: (id, hook) ->
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    if typeof hook is 'function'
      event.add hook
      return this
    return event

  hookLeft: (id, hook) ->
    if typeof hook isnt 'function'
      throw TypeError '`hook` must be a function'
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    event.add hook, -1
    return this

  hookRight: (id, hook) ->
    if typeof hook isnt 'function'
      throw TypeError '`hook` must be a function'
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    event.add hook, 1
    return this

  hookModules: (exts, hook) ->
    if Array.isArray exts
      exts.forEach (ext) => @hook 'module' + ext, hook
    else @hook 'module' + exts, hook

  _configure: ->
    @_config = {}
    try
      @_events = events = {}
      @_format.plugins?.forEach (plugin) =>
        plugin.call this

      if config = @_project.config[@_format.name]
        config.call this

      if events.config
        events.config.emit()
        events.config = null

    catch err
      cush.emit 'error',
        message: 'Failed to configure bundle'
        error: err
        root: @root.path
      return this

    @_invalidate() if @valid
    return this

  _build: -> try
    @valid = true
    time = process.hrtime()
    bundle = await build this
    if @valid
      time = process.hrtime time
      @elapsed = Math.ceil time[0] * 1e3 + time[1] * 1e-6

      # Force rebuild when dependencies are missing.
      if @missed.length
        @_invalidate()

    # Return the payload.
    return bundle

  catch err
    # Errors are ignored when the next build is automatic.
    if @valid
      @_invalidate()
      throw err

  # Invalidate the current build, and disable automatic rebuilds
  # until the next build is triggered manually.
  _invalidate: ->
    @valid = false
    @_result = null
    return

  # Invalidate the current build, and trigger an automatic rebuild.
  _rebuild: ->
    if @valid
      @valid = false

      if @_result
        @_result = @_result
          .then noEarlier 200 + Date.now()
          .then @_build.bind this
        return

      @_build()
      return

  # Return a Module object for the given file object.
  _getModule: (file, pack) ->
    if !mod = @modules[file.id]
      # New modules are put in the previous build's module cache.
      # When the new build finishes, old modules are released.
      @modules[file.id] = mod = {
        file, pack
        content: null
        deps: null    # ordered dependency objects
        map: null     # sourcemap
        ext: null     # file extension
      }

    return mod

  # Run hooks for a module.
  _loadModule: (mod) ->
    {ext} = mod
    if event = @_events['module' + ext]
      {hooks} = event
      for i in [0 ... hooks.length]
        await hooks[i] mod
        if mod.ext isnt ext
          return @_loadModule mod

  _unloadModule: (id) ->
    if mod = @modules[id]
      mod.content = null
      @_rebuild()

  _unloadModules: ->
    @_invalidate()
    @modules.forEach (mod) ->
      mod.content = null

  # Run hooks for a package.
  _loadPackage: (pack) ->
    Promise.all @_events.package.hooks.map (hook) -> hook pack

  _dropPackage: (pack) ->
    pack.bundles.delete this
    if !pack.bundles.size
      pack._unload()
    return this

  _joinModules: (modules) ->
    throw Error 'Bundle format must override `_joinModules`'

  _wrapSourceMapURL: (url) ->
    throw Error 'Bundle format must override `_wrapSourceMapURL`'

module.exports = Bundle

# Create a function that enforces a minimum delay.
noEarlier = (time) ->
  return -> new Promise (resolve) ->
    delay = Math.max 0, time - Date.now()
    delay and setTimeout(resolve, delay) or resolve()
