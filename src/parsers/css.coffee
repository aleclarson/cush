cssTokenize = require 'postcss/lib/tokenize'

exports['.css'] = (asset, pack) ->
  return if asset.deps

  tokenize = pack.tokenize or cssTokenize
  toks = tokenize
    css: asset.content
    error: onError

  # Default to working with postcss-scss
  toks.atrule or= 'at-word'
  toks.comment or= 'comment'
  toks.evalStrings ?= true
  toks.importWord or= '@import'
  toks.semi ?= true
  toks.space or= 'space'

  # Customizable helpers
  toks.getLength or= (prev) -> prev[1].length
  toks.isAtrule or= (curr) -> curr[0] is toks.atrule
  toks.isImport or= (curr) -> curr[1] is toks.importWord

  offset = 0
  prev = null
  curr = null
  next = ->
    if prev = curr
      offset += toks.getLength prev
    curr = toks.nextToken()
    return curr

  deps = []
  while next()
    type = curr[0]
    continue if toks.semi and type is ';'
    continue if type is toks.space or type is toks.comment
    break if !toks.isAtrule(curr) or !toks.isImport(curr)
    start = offset
    next() # skip ' '
    ref = next()[1]
    ref = eval(ref) if toks.evalStrings
    next() if toks.semi # skip ';'
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
