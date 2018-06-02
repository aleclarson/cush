{tokenizer, tokTypes} = require 'acorn'

# Only parses `require` calls,
# because `import` statements are transformed with sucrase.
exports.imports = (input) ->
  toks = tokenizer input
  next = toks.getToken.bind toks
  imps = []
  while tok = next()
    break if tok.type is tokTypes.eof

    if isRequire(tok) and (tok = getRequireArg next)
      imps.push
        id: tok.value
        start: tok.start
        end: tok.end

  return imps

isRequire = (tok) ->
  (tok.type is tokTypes.name) and (tok.value is 'require')

getRequireArg = (next) ->
  if next().type is tokTypes.parenL
    if (tok = next()).type is tokTypes.string
      if next().type is tokTypes.parenR
        return tok
