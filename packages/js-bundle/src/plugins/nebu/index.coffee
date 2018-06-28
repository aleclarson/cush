{evalFile, lazyRequire, mapSources} = require 'cush/utils'
cush = require 'cush'
path = require 'path'
fs = require 'saxon'

nebu = require '@cush/nebu'
nebu.acorn = require 'acorn'

module.exports = ->
  packs = new WeakMap
  shared =
    sourceMaps: true
    plugins: []

  if plugs = @get 'nebu.plugins'
    shared.plugins.push plugs

  doneHook = @hook 'nebu'

  @hookPackages (pack) ->
    if config = await loadConfig pack.path
      {plugins} = config
      Object.assign config, shared
      if Array.isArray plugins
        config.plugins = plugins.concat shared.plugins
      packs.set pack, config
      return

  @hookModules '.js', (mod) ->
    config = packs.get(mod.pack) or shared
    return if !config.plugins.length
    try
      config = Object.create config
      config.state = {}
      config.filename = mod.pack.resolve mod.file
      res = nebu.process mod.content, config
      doneHook.run mod, config.state
      if res.map
        res.content = res.js
        mapSources mod, res

    catch err
      cush.emit 'warning',
        message: 'nebu threw an error: ' +
          (cush.verbose and err.stack or err.message)
        file: config.filename
      return

# TODO: watch `nebu.config.js` for changes
loadConfig = (root) ->
  configPath = path.join root, 'nebu.config.js'
  if await fs.isFile configPath
    config = evalFile configPath
    if Array.isArray config
      plugins: config
    else config
  else null
