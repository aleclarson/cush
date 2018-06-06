{relative} = require '../utils'
path = require 'path'

scopedRE = /^((?:@[a-z._-]+\/)?[a-z._-]+)(?:\/(.+))?$/

Resolver = (bundle, resolved) ->
  {exts, missed} = bundle
  {target} = bundle.opts

  resolveImport = (parent, ref) ->
    {file, pack} = parent

    # ./ or ../
    if ref[0] is '.'
      id = relative file.name, ref
      if id is null
        cush.emit 'warning',
          message: 'Unsupported import path: ' + ref
          parent: bundle.relative parent
        return false

      # use the main module if referencing package root
      if !id and !id = resolveMain pack
        cush.emit 'warning',
          message: '"main" path is invalid: ' + pack.root
          package: pack.root
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
            package: pack.root
          return false

    else # absolute paths are forbidden 💥
      cush.emit 'warning',
        message: 'Import path must be relative'
        parent: bundle.relative parent
      return false

    await pack.crawl()
    if file = pack.search id, target, exts
      bundle._getModule file, pack
    else false

  # Resolve all dependencies of a module.
  return (parent) ->
    return if !parent.deps
    modules = {}
    parent.deps.forEach (dep, i) ->
      mod = dep.module
      if !mod or mod.file.time > bundle.time

        # Never resolve the same ref twice.
        if !mod = modules[dep.ref]
          modules[dep.ref] = mod =
            resolveImport parent, dep.ref
          resolved.push mod

        if mod = await mod
          dep.module = mod
          return

        # The module cannot be found.
        missed.push [parent, i]
        return

      # The module is good to reuse. ✨
      if !modules[dep.ref]
        modules[dep.ref] = mod
        resolved.push mod
      return

module.exports = Resolver

# Resolve the main module of a package.
resolveMain = (pack) ->
  if id = pack.data.main
    if id[0] is '.'
      relative '', id
    else id
  else 'index'
