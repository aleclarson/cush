acorn = require 'acorn'
tt = acorn.tokTypes

exports['.js'] = (asset) ->
  return if asset.deps

  toks = acorn.tokenizer asset.content
  next = toks.getToken.bind toks
  deps = []
  while tok = next()
    break if tok.type is tt.eof

    # `import` statements are already transformed.
    if isRequire(tok) and (tok = getRequireArg next)
      deps.push
        ref: tok.value
        asset: null
        start: tok.start
        end: tok.end

  asset.deps = deps
  return

isRequire = (tok) ->
  (tok.type is tt.name) and (tok.value is 'require')

getRequireArg = (next) ->
  if next().type == tt.parenL
    tok = next()
    if tok.type == tt.string and next().type == tt.parenR
      return tok
