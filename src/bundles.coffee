{findPackage, merge, sha256, uhoh} = require './utils'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

# Bundle constructor
cush.bundle = (main, opts) ->

  if !opts or typeof opts.target isnt 'string'
    uhoh '`target` option must be a string', 'NO_TARGET'

  if !ext = path.extname main
    uhoh '`main` has no extension: ' + main, 'BAD_MAIN'

  if !path.isAbsolute main
    main = path.resolve main

  if !id = opts.id
    id = sha256(main, 10) + '.' + opts.target
    id += '.dev' if opts.dev
    opts.id = id

  # Find the main module.
  file = main.slice(0, -ext.length) + '.' + opts.target + ext
  if !fs.isFile(file) and !fs.isFile(file = main)
    uhoh '`main` does not exist: ' + main, 'BAD_MAIN'

  # Find the root package.
  if !root = findPackage main
    uhoh '`main` has no package: ' + main, 'BAD_MAIN'

  # Load the project.
  project = cush.project root
  opts.format or= project.get(main).format

  # Resolve the bundle format.
  if !Bundle = opts.format or resolveFormat main
    uhoh '`main` has no bundle format: ' + main, 'NO_FORMAT'

  # Create the bundle.
  bundle = new Bundle opts

  # Load the root package.
  pack = bundle._loadPackage root
  bundle.root = pack

  # Load the main module.
  main = path.relative root, file
  bundle.main = bundle._loadAsset main, pack
  pack.assets[main] or= bundle.main

  # Watch the project.
  bundle.project = project.watch()
  project.bundles.add bundle
  return bundle

#
# Helpers
#

resolveFormat = (main) ->
  ext = path.extname main
  for id, format of cush.formats
    if format.exts.includes ext
      return format
