{mapSources} = require 'cush/utils'
cush = require 'cush'
path = require 'path'

tforms = {modules: false}

module.exports = ->
  buble = require '@cush/buble'
  buble.parse = require('acorn').parse

  {root} = this
  @hookModules '.js', (mod) ->
    filename = path.join mod.pack.root, mod.file.name

    try res = buble.transform mod.content,
      includeContent: false
      objectAssign: 'Object.assign'
      transforms: tforms
      source: path.relative root, filename

    catch err
      cush.emit 'warning',
        message: 'buble threw an error: ' +
          (cush.verbose and err.stack or err.message)
        file: filename
      return

    if res.map
      mapSources mod, res
