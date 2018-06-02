cush = require 'cush'

self = exports

self.type = 'js'

self.exts = ['.js', '.ts', '.coffee', '.jsx', '.tsx']

self.plugins = [
  # require './plugins/buble'
  require './plugins/nebu'
  # require './plugins/uglify'
]

self.mixin =

  _joinModules: (modules) ->
    console.log modules.map @relative, @
    return modules
      .map (mod) -> mod.content
      .join '\n'
