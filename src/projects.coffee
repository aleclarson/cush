{evalFile} = require './utils'
cush = require 'cush'
path = require 'path'
wch = require 'wch'
fs = require 'fs'

projects = Object.create null

cush.project = (root) ->
  projects[root] or= new Project root

class Project
  constructor: (root) ->
    configPath = path.join root, 'cush.config.js'
    @root = root
    @config = evalFile(configPath) or {}
    @bundles = new Set
    @watcher =
      wch.stream root,
        only: ['cush.config.js']
      .on 'data', (evt) =>
        @config = evalFile(configPath) or {}
        @bundles.forEach (bundle) ->
          bundle._configure()

  drop: (bundle) ->
    @bundles.delete bundle
    if @bundles.size is 0
      @watcher.destroy()
      delete projects[@root]