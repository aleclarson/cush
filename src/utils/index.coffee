
each = (obj, fn, ctx) ->
  if obj
    for key, val of obj
      fn.call ctx, val, key
    return

noop = -> # do nothing

module.exports =
  ErrorTracer: require './ErrorTracer'
  crawl: require './crawl'
  each: each
  evalFile: require './evalFile'
  extRegex: require './extRegex'
  findPackage: require './findPackage'
  getCallSite: require './getCallSite'
  getModule: require './getModule'
  ignored: require './ignored'
  lazyRequire: require './lazyRequire'
  mapSources: require './mapSources'
  merge: require './merge'
  noop: noop
  sha256: require './sha256'
  uhoh: require './uhoh'
