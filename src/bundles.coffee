{findPackage, sha256} = require './utils'
assert = require 'invariant'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

Bundle = require './Bundle'

# Bundle cache
cush.bundles = Object.create null

# Bundle constructor
cush.bundle = (main, opts) ->
  assert opts and opts.target, '`target` option must be defined'
  assert ext = path.extname(main), '`main` path must have an extension'

  if !path.isAbsolute main
    main = path.resolve main

  id = sha256(main).slice(0, 7) + '.' + opts.target
  id += '.dev' if opts.dev
  if bundle = cush.bundles[id]
    return bundle

  # Get the main package.
  if root = findPackage main
    pack = cush.package root
  else throw Error '`main` path must be inside a package'

  # Find the main module.
  file = main.slice(0, -ext.length) + '.' + opts.target + ext
  fs.isFile(file) or assert fs.isFile(file = main), '`main` path must be a file'

  # Create the main module.
  main = path.relative root, file
  pack.files[main] or= true

  # Create the bundle.
  bundle = new Bundle opts.dev, opts.target
  bundle.id = id
  bundle.main = bundle._getModule pack.file(main), pack
  loadFormat bundle

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
  bundle._form = form

  if form.mixin
    for key, value of form.mixin
      if key[0] is '_'
        Object.defineProperty bundle, key, {value}
      else bundle[key] = value
    return
  return
