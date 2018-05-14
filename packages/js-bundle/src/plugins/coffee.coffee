{lazyRequire} = require 'cush/utils'
cush = require 'cush'

cush.plugin 'coffee', ->

  @on 'package:add', (pack) ->
    pack.

  @on 'file:add', (file) ->
