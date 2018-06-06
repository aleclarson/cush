{mapSources} = require 'cush/utils'
cush = require 'cush'
path = require 'path'

tforms = {modules: false}

module.exports = (bundle, opts) ->
  buble = require '@cush/buble'
  buble.parse = require('acorn').parse

  @loadModules '.js', (mod) ->

    try res = buble.transform mod.content,
      includeContent: false
      objectAssign: 'Object.assign'
      transforms: tforms

    catch err
      cush.emit 'warning',
        message: 'buble threw an error: ' +
          (cush.verbose and err.stack or err.message)
        file: path.join mod.pack.root, mod.file.name
      return

    if mod.content isnt res.content
      mapSources mod, res
