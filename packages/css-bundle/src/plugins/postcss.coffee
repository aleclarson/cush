postcss = require 'postcss'
cara = require 'cara'

# postcss without plugins
noop = postcss()

# file types we should parse
exts = new Set ['.css']

# plugins used by every package
globalConfig =
  plugins: []
  map:
    inline: false
    annotation: false
    sourcesContent: false

parseFile = ->
  @pack.postcss.parse @data, @pack.config.postcss

# TODO: merge in global plugins
cara.plugin 'postcss', ->

  loadConfig = (pack) ->
    if config = pack.eval 'postcss.config.js'
      deepMerge config, globalConfig
      pack.postcss = postcss config.plugins
      pack.config.postcss = config
      return

  @on 'package:add', (pack) ->
    loadConfig pack

    if pack.mutable
      pack.watch 'postcss.config.js', ->
        loadConfig pack

  @on 'file:add', (file) ->
    if exts.has file.ext
      file.parse = parseFile
      return

  #
  # Plugin properties
  #

  exts: exts

  set: (key, val) ->
    globalConfig[key] = val
    return

  use: (plug) ->
    globalConfig.plugins.push plug
    return
