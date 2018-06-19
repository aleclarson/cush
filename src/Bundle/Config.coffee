{evalFile} = require 'cush/utils'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

class BundleConfig
  constructor: (@dev, @target) ->
    @_opts = {}
    @_hooks = Object.create null
    @_moduleHooks = Object.create null
    @_packageHooks = []

  get: (path) ->
    if typeof path is 'string'
      path = path.split '.'

    vals = @_opts
    last = path.length - 1
    for i in [0 ... last]
      vals = vals[path[i]]
      return if !vals?
      if vals.constructor isnt Object
        path = path.slice(0, i + 1).join '.'
        throw TypeError "'#{path}' is not an object"

    return vals[path[last]]

  set: (path, val) ->
    if typeof path is 'string'
      path = path.split '.'

    vals = @_opts
    last = path.length - 1
    for i in [0 ... last]
      prev = vals
      vals = prev[path[i]]
      if !vals?
        prev[path[i]] = vals = {}
      else if vals.constructor isnt Object
        path = path.slice(0, i + 1).join '.'
        throw TypeError "'#{path}' is not an object"

    vals[path[last]] = val
    return this

  plugin: (names) ->
    if !Array.isArray names
      names = [names]

    names.forEach (name) =>
      deps = @pack.devDependencies
      if !deps or !dep = deps['cush-plugin-' + name]
        throw Error "Plugin '#{name}' used by '#{@root}' is not installed"

      dep =
        if /^file:/.test dep
        then path.resolve @root, dep.slice 5
        else path.join @root, 'node_modules', 'cush-plugin-' + name

      evalFile(dep).call this

  hook: (id, fn) ->

    if arguments.length is 2

      if hook = @_hooks[id]
        return hook.add fn

      throw Error "Hook does not exist: '#{id}'"

    if @_hooks[id]
      throw Error "Hook already exists: '#{id}'"

    @_hooks[id] = hook = new BundleHook
    return hook

  hookModules: (ext, fn) ->

    if Array.isArray ext
      ext.forEach (ext) =>
        @hookModules ext, fn
      return fn

    hooks = @_moduleHooks[ext] or= []
    hooks.push fn
    return fn

  hookPackages: (fn) ->
    @_packageHooks.push fn
    return fn

  relative: (mod) ->
    throw Error 'Expected a module' if !mod or !mod.pack
    path.join(mod.pack.root, mod.file.name).slice @root.length + 1

  _load: (pack, form) ->
    @root = pack.root
    @pack = pack.data

    hooks = @_hooks
    hooks.config = new BundleHook
    hooks.bundle = new BundleHook
    try
      form.plugins?.forEach (plugin) =>
        plugin.call this

      config = path.join @root, 'cush.config.js'
      if fs.isFile config
        if config = evalFile config
          if config = config[form.name]
            config.call this

      hooks.config.run()
      hooks.config = null

    catch err
      cush.emit 'error',
        message: 'Failed to configure bundle'
        error: err
        root: @root
      return

    hooks._module = @_moduleHooks
    hooks._package = @_packageHooks
    hooks

module.exports = BundleConfig

class BundleHook
  constructor: ->
    @array = []

  add: (fn) ->
    @array.push fn
    return fn

  run: (...args) ->
    @array.forEach (fn) -> fn ...args

  each: (iter, ctx) ->
    @array.forEach iter, ctx
