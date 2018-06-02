{evalFile, lazyRequire, mapSources} = require 'cush/utils'
nebu = require 'nebu'
cush = require 'cush'
path = require 'path'
fs = require 'saxon'

# TODO: inject acorn
module.exports = (bundle, opts) ->
  packs = new WeakMap
  shared =
    sourceMaps: true
    plugins: [
      opts.dev and require('./nebu/strip-dev')
      opts.nebu?.plugins
    ]

  @loadPackages (pack) ->
    if config = await loadConfig pack.root
      {plugins} = config
      Object.assign config, shared
      if Array.isArray plugins
        config.plugins = plugins.concat shared.plugins

    packs.set pack, config or shared
    return

  @loadModules '.js', (mod) ->
    config = Object.create packs.get(mod.pack)
    config.filename = path.join mod.pack.root, mod.file.name
    try
      res = nebu.process mod.content, config
      if mod.content isnt res.js
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
  if await fs.isFile root
    config = evalFile configPath
    if Array.isArray config
      plugins: config
    else config
  else null
