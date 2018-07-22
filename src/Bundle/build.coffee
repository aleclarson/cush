{loadAsset, printStats} = require '../workers'
{each} = require '../utils'
Resolver = require './Resolver'
elaps = require 'elaps'
cush = require 'cush'

resolved = Promise.resolve()

build = (bundle, state) ->
  assets = []    # ordered assets
  loaded = []    # sparse asset map for deduping
  packages = []  # ordered packages

  queue = []     # queued assets
  missing = []   # missing dependencies
  resolve = Resolver bundle, queue, missing
  resolvedCount = 0

  readTimer = elaps.lazy()
  resolveTimer = elaps.lazy()

  assetHook = bundle.hook 'asset'
  ownerHook = bundle.hook 'package'

  loadAsset = (asset) ->
    resolvedCount += 1
    return if loaded[asset.id]
    loaded[asset.id] = true
    assets.push asset

    {owner} = asset
    if packages.indexOf(owner) == -1
      packages.push owner
      owner.missedAsset = false
      owner.missedPackage = false
      ownerHook.emit owner, state

    # Wait for the load queue to be cleared.
    await resolved

    # Read the asset.
    if asset.content == null
      lap = readTimer.start()
      await readAsset asset
      lap.stop()

    # Resolve its dependencies.
    if asset.deps
      lap = resolveTimer.start()
      await resolve asset
      lap.stop()

    # Let plugins inspect/alter the asset.
    assetHook.emit asset, state
    return

  # Load the main module.
  await loadAsset bundle.main

  {IDLE, BUSY} = require('../Bundle').Status

  # Keep loading modules until stopped or finished.
  while bundle.status == BUSY and queue.length
    await mapFlush queue, loadAsset

  # Exit early for cancelled builds.
  if bundle.status != BUSY
    return null

  # Cancel the build if dependencies are missing.
  if missing.length
    state.missing = missing
    bundle.status = IDLE
    return null

  readTimer.print 'loaded %n assets in %t'
  resolveTimer.print 'resolved %O dependencies in %t', resolvedCount
  printStats bundle

  dropUnusedPackage = (pack) ->
    pack._unload() if packages.indexOf(pack) == -1

  # Purge unused packages.
  each bundle.packages, (versions, name) ->
    versions.forEach dropUnusedPackage

  concatTimer = elaps 'concatenated %O assets in %t', assets.length

  # Concatenate the assets.
  result = await bundle._concat assets, packages

  if /\bcush\b/.test process.env.DEBUG
    setImmediate -> concatTimer.stop true

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
