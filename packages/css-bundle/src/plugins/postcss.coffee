{evalFile, mapSources} = require 'cush/utils'
cush = require 'cush'
path = require 'path'

postcss = null
packs = new WeakMap

module.exports = ->
  @hookPackages loadConfig
  @hookModules '.css', (mod) =>
    if config = packs.get mod.pack
      config = Object.create config
      filename = path.join mod.pack.root, mod.file.name
      config.from = path.relative @root, filename
      config.syntax = mod.syntax
      postcss(config.plugins)
        .process mod.content, config
        .then (res) ->

          res.warnings().forEach (msg) ->
            cush.emit 'warning',
              message: msg.toString()
              file: filename

          res.map = res.map.toJSON()
          mapSources [res, mod],
            includeContent: false

#
# Internal
#

sourceMaps =
  inline: false
  annotation: false
  sourcesContent: false

# TODO: watch `postcss.config.js` for changes
loadConfig = (pack) ->
  if config = packs.get pack
    return config
  if config = evalFile 'postcss.config.js'
    postcss or= require 'postcss'
    config.to = ''
    config.map = sourceMaps
    packs.set pack, config
    return config
