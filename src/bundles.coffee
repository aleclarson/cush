{findPackage, sha256} = require './utils'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

Bundle = require './Bundle'

# Bundle cache
cush.bundles = Object.create null

# Bundle constructor
cush.bundle = (main, opts) ->
  if !opts or !opts.target
    throw Error '`target` option must be defined'
  if !ext = path.extname main
    throw Error '`main` path must have an extension'

  if !path.isAbsolute main
    main = path.resolve main

  id = sha256(main).slice(0, 7) + '.' + opts.target
  id += '.dev' if opts.dev
  if bundle = cush.bundles[id]
    return bundle

  # Find the root package.
  if !root = findPackage main
    throw Error '`main` path must be inside a package'
  pack = cush.package root

  # Find the main module.
  if !fs.isFile file = main.slice(0, -ext.length) + '.' + opts.target + ext
    if !fs.isFile file = main
      throw Error '`main` path must be a file'

  # Create the main module.
  main = path.relative root, file
  pack.files[main] or= true

  # Create the bundle.
  bundle = new Bundle opts.dev, opts.target
  bundle.id = id
  bundle.root = pack
  bundle.main = bundle._getModule pack.file(main), pack
  loadFormat bundle

  # Load the project.
  project = cush.project pack.path
  project.bundles.add bundle
  bundle._project = project

  cush.bundles[id] = bundle
  return bundle._configure()

#
# Internal
#

loadFormat = (bundle) ->
  ext = bundle.main.file.ext
  form = cush.formats.find (form) ->
    if form.match then form.match bundle
    else if form.exts then form.exts.includes ext
    else false

  if !form
    throw Error 'Bundle has no matching format'

  if !form.name
    throw Error 'Bundle format has no "name" property'

  bundle.exts = form.exts and form.exts[..] or []
  bundle._format = form

  if form.mixin
    for key, value of form.mixin
      if key[0] is '_'
        Object.defineProperty bundle, key, {value}
      else bundle[key] = value
    return
  return
