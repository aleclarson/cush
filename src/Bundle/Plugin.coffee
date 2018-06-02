
class Plugin
  constructor: (hooks) ->
    @_hooks = hooks

  loadPackages: (hook) ->
    @_hooks.loadPackage.push hook
    return

  loadModules: (ext, hook) ->
    hooks = @_hooks.loadModule[ext] ?= []
    hooks.push hook
    return

module.exports = Plugin
