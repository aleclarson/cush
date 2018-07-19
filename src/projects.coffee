{evalFile} = require './utils'
Emitter = require '@cush/events'
cush = require 'cush'
path = require 'path'
log = require('lodge').debug('cush')
wch = require 'wch'
fs = require 'fs'

cush.projects =
  projects = Object.create null

cush.project = (root) ->
  projects[root] or= new Project root

class Project extends Emitter
  constructor: (root) ->
    super()
    @root = root
    @config = evalFile(path.join root, 'cush.config.js') or {}
    @watcher = null
    @bundles = new Set

  watch: ->
    @watcher or=
      wch.stream @root,
        only: ['cush.config.js']
      .on 'data', (evt) =>
        @config = evalFile(evt.path) or {}
        @bundles.forEach (bundle) ->
          bundle._unload()
          bundle._rebuild()
        @emit 'config'
    return this

  drop: (bundle) ->

    if !arguments.length
      @bundles.forEach (bundle) ->
        bundle.destroy()
      return true

    @bundles.delete bundle
    if @bundles.size is 0
      @watcher.destroy()
      delete projects[@root.path]

  _configure: (bundle) ->

    # format-specific configuration
    if fn = @config[bundle.constructor.id]
      try await fn.call bundle
      catch err
        log.error err

    # bundle-specific configuration
    config = @config.bundles[bundle.main.name]
    if fn = config?.init
      try await fn.call bundle
      catch err
        log.error err
