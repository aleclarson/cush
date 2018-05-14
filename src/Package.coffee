{eval} = require './utils'
path = require 'path'
cush = require 'cush'
wch = require 'wch'
fs = require 'fsx'

class Package
  constructor: (root, conf) ->
    @path = root
    @conf = null
    @files = null
    @mutable = !isNodeModule(root) or fs.isLink(root)

  get: (name) ->
    file = @files[name]
    file isnt true and file or null

  load: (name) ->
    file = @files[name]
    if file is true
      file = new File name, this
    file or null

  crawl: ->
    files = Object.create null

    opts =
      exclude: cush.config('exclude').slice()

    files = await wch.query @path, opts
    console.info files

    # if @mutable
    #   stream = wch.stream @path,

isNodeModule = (root) ->
  /\/node_modules\//.test root

module.exports = Package
