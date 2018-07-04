cush = require 'cush'

def = (key, value) ->
  Object.defineProperty cush, key, {value}

#
# Parsers
#

cush.parsers =
  '.css': require './parse/css'
  '.js': require './parse/js'

def '_parseImports', (mod) ->
  if parse = cush.parsers[mod.ext]
    parse.imports mod.content, mod
  else []

#
# Transformers
#

assign = (a, b) ->
  a[k] = b[k] for k of b
  return a

cush.transformers = [
  require './transform/coffee'
  require './transform/sucrase'
].reduce assign, {}
