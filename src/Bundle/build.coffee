Resolver = require './Resolver'
loadFile = require '../fs/loadFile'
noop = require 'noop'
cush = require 'cush'

build = (bundle, opts) ->
  timestamp = Date.now()
  bundle.missed = []

  files = []     # ordered files
  packages = []  # ordered packages
  modules = []   # sparse module map (file => module)

  pending = []
  resolve = Resolver bundle, pending

  loadModule = (mod) ->
    {file, pack} = mod

    if !modules[file.id]
      modules[file.id] = mod
      files.push file
    else return

    # Cache the module and its package.
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
      await parseImports mod

    # Resolve any imports.
    if mod.deps
      await resolve mod

  # Load the main module.
  await loadModule bundle.main

  # Keep loading modules until stopped or finished.
  while bundle.valid and pending.length
    await Promise.all (await drain pending).map loadModule

  # Update the build time.
  bundle.time = timestamp

  # Exit early for invalid bundles.
  if !bundle.valid or bundle.missed.length
    return null

  # Purge unused packages.
  bundle.packages.forEach (pack) ->
    ~packages.indexOf(pack) or bundle._dropPackage pack

  bundle.files = files
  bundle.modules = modules
  bundle.packages = packages

  # Create the bundle string.
  bundle._joinModules()

module.exports = build

# Wrap the given queue with Promise.all before emptying it.
drain = (queue) ->
  promise = Promise.all queue
  queue.length = 0
  promise

# Parse the imports of a module, and reuse old resolutions.
parseImports = (mod) ->

  if mod.deps
    prev = Object.create null
    mod.deps.forEach (dep) ->
      prev[dep.ref] = dep.module
      return

  mod.deps = await cush._parseImports mod
  if prev then mod.deps.forEach (dep) ->
    dep.module = prev[dep.ref] or null
    return
