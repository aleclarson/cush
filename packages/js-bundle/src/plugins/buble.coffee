{lazyRequire} = require 'cush/utils'

buble = null

# TODO: inject acorn
exports.transform = (mod, bundle) ->
  buble ?= await lazyRequire 'buble'
