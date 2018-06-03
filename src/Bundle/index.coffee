{merge, findPackage, sha256} = require 'cush/utils'
sorcery = require '@cush/sorcery'
Plugin = require './Plugin'
assert = require 'assert'
build = require './build'
noop = require 'noop'
path = require 'path'
cush = require 'cush'

class Bundle
  constructor: (opts) ->
    @main = null
    @opts = opts
    @map = null       # sourcemap object
    @valid = false    # not outdated?
    @elapsed = null   # time spent building
    @missed = []      # missing dependencies
    @modules = []     # used modules
    @packages = []    # used packages
    @_result = null   # build promise
    @_hooks =
      loadPackage: []
      loadModule: {}

  use: (init) ->
    if typeof init isnt 'function'
      init = require init
    plug = new Plugin @_hooks
    init.call plug, this, @opts
    return this

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

  # Return a Module object for the given filename.
  _getModule: (id, pack) ->
    {target} = @opts

    if ext = path.extname id
      # prefer target-specific modules
      pref = id.slice(0, -ext.length) + '.' + target + ext
      file = pack.file(pref) or pack.file(id)
    else
      file = matchFile id, pack, target, @exts
      file ?= matchFile id + '/index', pack, target, @exts

    if !file
      return false

    if !mod = @modules[file.id]
      # New modules are put in the previous build's module cache.
      # When the new build finishes, old modules are released.
      @modules[file.id] = mod = {
        file, pack
        content: null
        imports: null
        map: null
        ext: null
      }

    return mod

  # Run hooks for a module.
  _loadModule: (mod) ->
    if hooks = @_hooks.loadModule[mod.ext]
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
    Promise.all @_hooks.loadPackage.map (hook) -> hook pack

  _dropPackage: (pack) ->
    pack.bundles.delete this
    if !pack.bundles.size
      pack._purge()
    return this

  _joinModules: (modules) ->
    throw Error 'Bundle format must override `_joinModules`'

module.exports = Bundle

# Try every implicit extension until the ambiguous filename is resolved.
matchFile = (id, pack, target, exts) ->
  # prefer target-specific modules
  pref = id + '.' + target
  for ext in exts
    file = pack.file(pref + ext) or pack.file(id + ext)
    return file if file

# Create a function that enforces a minimum delay.
noEarlier = (time) ->
  return -> new Promise (resolve) ->
    delay = Math.max 0, time - Date.now()
    delay and setTimeout(resolve, delay) or resolve()
