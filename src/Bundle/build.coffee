{loadAsset, printStats} = require '../workers'
{each} = require '../utils'
Resolver = require './Resolver'
elaps = require 'elaps'
cush = require 'cush'

resolved = Promise.resolve()

build = (bundle, state) ->
  timestamp = Date.now()

  assets = []    # ordered assets
  loaded = []    # sparse asset map for deduping
  packages = []  # ordered packages

  queue = []     # queued assets
  missing = []   # missing dependencies
  resolve = Resolver bundle, queue, missing

  t1 = elaps.lazy 'read %n assets'
  t2 = elaps.lazy 'resolve dependencies'

  assetHook = bundle.hook 'asset'
  loadAsset = (asset) ->
    return if loaded[asset.id]
    loaded[asset.id] = true
    assets.push asset

    if packages.indexOf(asset.owner) == -1
      packages.push asset.owner

    # Wait for the load queue to be cleared.
    await resolved

    # Read the asset.
    if asset.content == null
      lap = t1.start()
      await readAsset asset
      lap.stop()

    # Resolve its dependencies.
    if asset.deps
      lap = t2.start()
      await resolve asset
      lap.stop()

    # Let plugins inspect/alter the asset.
    assetHook.emit asset, state
    return

  # Load the main module.
  await loadAsset bundle.main

  # Keep loading modules until stopped or finished.
  while bundle.valid and queue.length
    await mapFlush queue, loadAsset

  # The bundle is invalid if dependencies are missing.
  if missing.length
    state.missing = missing
    bundle._invalidate()

  # Exit early for invalid bundles.
  if !bundle.valid
    return null

  # Update the build time.
  bundle.time = timestamp

  t1.print()
  t2.print()
  printStats bundle

  dropUnusedPackage = (pack) ->
    pack._unload() if packages.indexOf(pack) == -1

  # Purge unused packages.
  each bundle.packages, (versions, name) ->
    versions.forEach dropUnusedPackage

  # Concatenate the assets.
  t3 = elaps 'concatenate assets'
  result = await bundle._concat assets, packages
  t3.stop()
  return result

module.exports = build

# Combine all promises in the given queue before clearing it.
mapFlush = (queue, iter) ->
  promise = Promise.all queue.map iter
  queue.length = 0
  promise

readAsset = (asset) ->

  if asset.deps
    prev = Object.create null
    asset.deps.forEach (dep) ->
      prev[dep.ref] = dep.asset
      return

  await asset._load()

  if prev and asset.deps
    asset.deps.forEach (dep) ->
      dep.asset = prev[dep.ref] or null
      return
