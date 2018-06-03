{relative} = require '../utils'
loadFile = require '../fs/loadFile'
sorcery = require 'sorcery'
noop = require 'noop'
path = require 'path'
cush = require 'cush'

build = (bundle, opts) ->
  if !bundle.main
    throw Error 'Bundle must have a main module'

  aborted = ->
    if !bundle.valid
      aborted = noop.true
      return true

  {missed} = bundle
  missed.length = 0

  modules = []
  packages = []

  loading = []   # loading dependencies
  resolved = []  # ordered dependencies (with dupes)

  loadModule = (mod) ->
    {file, pack} = mod

    # Cache the module and its package.
    modules[file.id] = mod
    if packages.indexOf(pack) is -1
      packages.push pack

      # Load packages not in the previous build.
      if !bundle.packages[pack.id]
        pack.bundles.add bundle
        await bundle._loadPackage pack

    # Read file, then apply global plugins.
    if file.content is null
      await loadFile file, mod.pack

    # Apply bundle plugins.
    if mod.content is null
      mod.content = file.content
      mod.map = file.map
      mod.ext = file.ext
      await bundle._loadModule mod
      mod.imports = await cush._parseImports mod

    return mod

  resolveImports = (mod) ->
    deps = Object.create null
    mod.imports.forEach ({id}, i) ->
      loading.push do ->
        dep = deps[id]

        # Reserve our position.
        pos = resolved.push(null) - 1

        # Avoid resolving the same module twice.
        if dep is undefined
          deps[id] = dep =
            resolveImport id, mod, bundle

        # Wait for the module to be resolved.
        resolved[pos] = dep = await dep

        # The module cannot be found.
        if dep is false
          missed.push [mod, i]
          return

        # Ensure the module is loaded once.
        if !modules[dep.file.id]
          return loadModule dep

  # Load the main module.
  loaded = [await loadModule bundle.main]
  resolved[0] = bundle.main

  # Resolve the imports of every loaded module.
  while !aborted()
    loaded.forEach (mod) ->
      if mod and mod.imports
        resolveImports mod

    # Wait for imports to be resolved and loaded.
    if loading.length
      loaded = await Promise.all loading
      loading.length = 0
    else break

  if aborted() or missed.length
    return null

  # Purge unused packages.
  bundle.packages.forEach (pack) ->
    ~packages.indexOf(pack) or bundle._dropPackage pack

  bundle.modules = modules
  bundle.packages = packages

  # Create the bundle string.
  bundle._joinModules resolved

module.exports = build

#
# Internal
#

scopedRE = /^((?:@[a-z._-]+\/)?[a-z._-]+)(?:\/(.+))?$/

resolveImport = (ref, mod, bundle) ->
  {file, pack} = mod

  # ./ or ../
  if ref[0] is '.'
    id = relative file.name, ref
    if id is null
      cush.emit 'warning',
        message: 'Unsupported import path: ' + ref
        module: mod
      return false

    # use the main module if referencing package root
    if !id and !id = resolveMain pack
      cush.emit 'warning',
        message: '"main" path is invalid: ' + pack.root
        package: pack
      return false

  # node_modules
  else if !path.isAbsolute ref
    if match = scopedRE.exec ref

      deps = pack.data.dependencies
      if !deps or !deps[match[1]]
        return false

      if !pack = pack.require match[1]
        return false

      # use the main module if nothing follows the package name
      if !id = match[2] or resolveMain pack
        cush.emit 'warning',
          message: '"main" path is invalid: ' + pack.root
          package: pack
        return false

  else # absolute paths are forbidden 💥
    cush.emit 'warning',
      message: 'Import path must be relative'
      module: mod
    return false

  await pack.crawl()
  bundle._getModule id, pack

resolveMain = (pack) ->
  if id = pack.data.main
    if id[0] is '.'
      relative '', id
    else id
  else 'index'
