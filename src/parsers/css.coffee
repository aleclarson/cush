cssTokenize = require 'postcss/lib/tokenize'

skipRE = /^(;|comment|space)$/

exports['.css'] = (asset, pack) ->
  return if asset.deps

  tokenize = pack.tokenize or cssTokenize
  toks = tokenize
    css: asset.content
    error: onError

  offset = 0
  prev = null
  curr = null
  next = ->
    if prev = curr
      offset += prev[1].length
    curr = toks.nextToken()

  deps = []
  while next()
    continue if skipRE.test curr[0]
    break if curr[0] isnt 'at-word'
    break if curr[1] isnt '@import'
    start = offset
    next() # skip ' '
    ref = next()[1].slice 1, -1
    next() # skip ';'
    next() # skip '\n'
    deps.push
      ref: ref
      asset: null
      start: start
      end: offset + 1

  asset.deps = deps
  return

#
# Helpers
#

after = (type, next) ->
  while tok = next()
    return next() if tok[0] is type

onError = (msg, line, column) ->
  e = new Error msg
  e.line = line
  e.column = column
  throw e