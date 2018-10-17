relative = require '@cush/relative'
cush = require 'cush'
path = require 'path'
log = require('lodge').debug('cush')

scopedRE = /^((?:@[a-z._-]+\/)?[a-z._-]+)(?:\/(.+))?$/

Resolver = (bundle, resolved, missing) ->
  {target} = bundle

  exts = bundle.get('exts')

  resolveImport = (parent, ref) ->
    {owner} = parent

    # ./ or ../
    if ref[0] is '.'
      id = relative parent.name, ref
      if id is null
        cush.emit 'warning',
          message: 'Unsupported import path: ' + ref
          parent: bundle.relative parent.path()
        return false

      if id is ''
        # use the main module if referencing package root
        id = resolveMain owner, bundle
        isMain = true

    # node_modules
    else if !path.isAbsolute ref
      if match = scopedRE.exec ref
        if !pack = owner.require match[1]

          if process.env.DEBUG
            log.warn 'Failed to resolve %O from %O', ref, bundle.relative parent.path()

          owner.missedPackage = true
          return false

        if !id = match[2]
          # use the main module if nothing follows the package name
          id = resolveMain pack, bundle
          isMain = true

    else # absolute paths are forbidden 💥
      cush.emit 'warning',
        message: 'Import path must be relative'
        parent: bundle.relative parent.path()
      return false

    pack or= owner
    if isMain and pack.main
      return pack.main

    pack.crawl()
    if asset = pack.search id, target, exts
      pack.main = asset if isMain
      return asset

    if process.env.DEBUG
      log.warn 'Failed to resolve %O from %O', ref, bundle.relative parent.path()

    pack.missedAsset = true
    return false

  # Resolve all dependencies of an asset.
  return (parent) ->
    assets = {}
    parent.deps.forEach (dep, i) ->
      {ref, asset} = dep

      if !asset or !asset.id or asset.time > bundle.time
        asset = assets[ref]

        # Never resolve the same ref twice.
        if asset is undefined
          assets[ref] = asset =
            resolveImport parent, ref

          if asset
            dep.asset = asset
            resolved.push asset
            return

        else if asset
          dep.asset = asset
          return

        # The asset cannot be found.
        missing.push [parent, dep]
        return

      # The asset is good to reuse. ✨
      if !assets[ref]
        assets[ref] = asset
        resolved.push asset
        return

    # Return the ordered assets.
    return assets

module.exports = Resolver

# Resolve the main module of a package.
resolveMain = (pack, bundle) ->

  if bundle._config.browser isnt false
    id = pack.data.browser

  if id or= pack.data.main
    if id[0] is '.'
      relative '', id
    else id
  else 'index'
