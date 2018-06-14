BundleConfig = require './Config'
build = require './build'
noop = require 'noop'
path = require 'path'
cush = require 'cush'

class Bundle
  constructor: (dev, target) ->
    @id = null        # bundle identifier
    @dev = dev        # development mode
    @target = target  # targeted platform
    @main = null      # the main module
    @exts = null      # implicit file extensions
    @time = 0         # time of last build
    @valid = false    # not outdated?
    @elapsed = null   # time spent building
    @files = []       # ordered files
    @packages = []    # ordered packages
    @modules = []     # sparse module map
    @missed = []      # missing dependencies
    @_form = null     # bundle format
    @_hooks = null    # bundle hooks
    @_result = null   # build promise

  read: ->
    @_result or= @_build()

  destroy: ->
    @_rev = 0  # cancel the current build

    # prevent future builds
    @read = noop.val Promise.resolve()

    @packages.forEach @_dropPackage.bind this
    return this

  relative: (mod) ->
    throw Error 'Expected a module' if !mod or !mod.pack
    path.relative @main.pack.root, path.join(mod.pack.root, mod.file.name)

  _configure: ->
    config = new BundleConfig @dev, @target
    @_hooks = config._load @main.pack, @_form
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
        @valid = false  # Disable automatic rebuilds (temporarily).
        @_result = null

    # Return the payload.
    return bundle

  catch err
    # Errors are ignored when the next build is automatic.
    if @valid
      @valid = false  # Disable automatic rebuilds (temporarily).
      @_result = null
      throw err

  _invalidate: ->
    if @valid
      @valid = false
      @_result = @_result
        .then noEarlier 200 + Date.now()
        .then @_build.bind this
    return this

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
    if hooks = @_hooks._module[mod.ext]
      i = -1; ext = mod.ext
      while ++i < hooks.length
        await hooks[i] mod
        if mod.ext isnt ext
          return @_loadModule mod

  _unloadModule: (id) ->
    if mod = @modules[id]
      mod.content = null
      @_invalidate()
    return this

  # Run hooks for a package.
  _loadPackage: (pack) ->
    Promise.all @_hooks._package.map (hook) -> hook pack

  _dropPackage: (pack) ->
    pack.bundles.delete this
    if !pack.bundles.size
      pack._unload()
    return this

  _joinModules: (modules) ->
    throw Error 'Bundle format must override `_joinModules`'

module.exports = Bundle

# Create a function that enforces a minimum delay.
noEarlier = (time) ->
  return -> new Promise (resolve) ->
    delay = Math.max 0, time - Date.now()
    delay and setTimeout(resolve, delay) or resolve()
