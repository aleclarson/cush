cssTokenize = require 'postcss/lib/tokenize'

skipRE = /^(;|comment|space)$/

exports.imports = (css, mod) ->
  tokenize = mod.syntax?.tokenize or cssTokenize
  toks = tokenize {css, error}

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
      module: null
      start: start
      end: offset + 1

  return deps

#
# Helpers
#

after = (type, next) ->
  while tok = next()
    return next() if tok[0] is type

error = (msg, line, column) ->
  e = new Error msg
  e.line = line
  e.column = column
  throw e
