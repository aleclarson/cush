{lazyRequire, mapSources} = require '../../utils'
semver = require 'semver'
cush = require 'cush'
path = require 'path'

# Loaded versions
brewed = {}

# TODO: use version present in `node_modules` by default?
brew = (pack) ->
  return if !deps = pack.data.devDependencies
  return if !version = deps['coffeescript'] or deps['coffee-script']

  # Check if a loaded version fits the bill.
  if match = semver.maxSatisfying Object.keys(brewed), version
    return brewed[match]

  # Install the required version.
  coffee = await lazyRequire 'coffeescript', version
  brewed[coffee.VERSION] = coffee
  coffee

transform = (file, pack) ->
  filename = pack.resolve file

  if !pack.coffee or= await brew pack
    cush.emit 'warning',
      message: 'Missing "coffeescript" dependency'
      file: filename
    return

  {compile} = pack.coffee
  res = compile file.content,
    filename: filename
    sourceMap: true
    bare: true

  res.content = res.js
  res.map = JSON.parse res.v3SourceMap
  mapSources file, res

  file.ext = '.js'
  return

exports['.coffee'] =
exports['.coffee.md'] =
exports['.litcoffee'] = transform