{evalFile, mapSources} = require 'cush/utils'
cush = require 'cush'
path = require 'path'

postcss = null
packs = new WeakMap

module.exports = ->
  @hook 'package', loadConfig
  @hookModules '.css', (mod) =>
    if config = packs.get mod.pack
      config = Object.create config
      filename = mod.pack.resolve mod.file
      config.from = path.relative @root.path, filename
      config.syntax = mod.syntax
      postcss(config.plugins)
        .process mod.content, config
        .then (res) ->

          res.warnings().forEach (msg) ->
            cush.emit 'warning',
              message: msg.toString()
              file: filename

          mapSources mod,
            content: res.css
            map: res.map.toJSON()

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
