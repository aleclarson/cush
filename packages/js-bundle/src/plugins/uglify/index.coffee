{mapSources, merge} = require 'cush/utils'
isObject = require 'is-object'
cush = require 'cush'
path = require 'path'

module.exports = ->
  @hook 'config', setup.bind this,
    sourceMap: {json: false}
    toplevel: true
    keep_fnames: @dev
    mangle: !@dev
    compress:
      sequences: !@dev
      dead_code: !@dev
      drop_debugger: !@dev
      inline: 0
      typeofs: false # IE10 compat
      hoist_props: false
      reduce_vars: false
      reduce_funcs: false
      side_effects: false
      collapse_vars: false
      global_defs:
        DEBUG: @dev
        ENV: @target

# Once the user's configuration is ready.
setup = (options) ->
  custom = @get 'uglify'
  return if custom is false

  if isObject custom
    merge options, custom

  uglify = require('@cush/uglify-js').minify

  @hookModules '.js', (mod) =>
    filename = mod.pack.resolve mod.file

    res = uglify mod.content, options
    if !res.error
      res.map.sources[0] = path.relative @root.path, filename
      return mapSources mod, res

    cush.emit 'warning',
      error: res.error
      file: filename
    return
