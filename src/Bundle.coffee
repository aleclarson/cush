{sha256, findPackage} = require './utils'
path = require 'path'
cush = require 'cush'
fs = require 'fsx'

class Bundle
  constructor: (main, opts = {}) ->

  read: (opts = {}) ->

Bundle.create = (main, opts = {}) ->
  pack = findPackage main
  pack = cush.packages.add pack
  pack.
  id = main

  # TODO: listen for 'file:change' events and update its module

reviveBundle = (id) ->
  props = require
