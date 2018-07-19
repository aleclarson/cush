{findPackage, sha256, uhoh} = require './utils'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

builtinParsers = [
  require.resolve('./parsers/js')
  require.resolve('./parsers/css')
]

# Bundle cache
cush.bundles = Object.create null

# Bundle constructor
cush.bundle = (main, opts) ->

  if !opts.target
    uhoh '`target` option is undefined', 'NO_TARGET'

  if !ext = path.extname main
    uhoh '`main` has no extension: ' + main, 'BAD_MAIN'

  if !path.isAbsolute main
    main = path.resolve main

  if !id = opts.id
    id = sha256(main, 10) + '.' + opts.target
    id += '.dev' if opts.dev
    opts.id = id

  if bundle = cush.bundles[id]
    return bundle

  # Find the main module.
  file = main.slice(0, -ext.length) + '.' + opts.target + ext
  if !fs.isFile(file) and !fs.isFile(file = main)
    uhoh '`main` does not exist: ' + main, 'BAD_MAIN'

  # Find the root package.
  if !root = findPackage main
    uhoh '`main` has no package: ' + main, 'BAD_MAIN'

  # Resolve the bundle format.
  if !Bundle = opts.format or resolveFormat main
    uhoh '`main` has no bundle format: ' + main, 'NO_FORMAT'

  # Create the bundle.
  bundle = new Bundle opts
  if Bundle.plugins
    bundle.plugins.unshift ...Bundle.plugins
  bundle.parsers.push ...builtinParsers

  # Load the root package.
  pack = bundle._loadPackage root
  bundle.root = pack

  # Load the main module.
  main = path.relative root, file
  bundle.main = bundle._loadAsset main, pack
  pack.assets[main] or= bundle.main

  # Load the project.
  project = cush.project root
  project.bundles.add bundle
  bundle.project = project.watch()

  cush.bundles[id] = bundle
  return bundle

#
# Helpers
#

resolveFormat = (main) ->
  ext = path.extname main
  for id, format of cush.formats
    if format.exts.includes ext
      return format
