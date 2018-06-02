tokenizer = require 'postcss/lib/tokenize'

skipRE = /^(;|comment|space)$/

exports.imports = (css) ->
  toks = tokenizer {css, error}
  next = toks.nextToken
  imps = []
  while tok = next()

    if tok[0] is 'at-word'
      break if tok[1] isnt '@import'
      start = tok[3]
      tok = after 'space', next
      if tok and tok[0] is 'string'
        imps.push
          id: eval tok[1]
          line: tok[2]

    else if !skipRE.test tok[0]
      break

  return imps

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
