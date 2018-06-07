cush = require 'cush'

self = exports

self.name = 'StyleSheet'

self.exts = ['.css', '.scss', '.sass']

self.plugins = [
  # require './plugins/postcss'
  require './plugins/sass'
]

self.mixin =

  _read: (opts) ->

  _initPackage: (pack) ->
    self.plugins.forEach (plug) ->
      plug.init
