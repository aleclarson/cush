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

  get: (main) ->
    if bundles = @config.bundles
      if !path.isAbsolute main
        main = path.relative @root, main
      return bundles[main] or {}
    return {}

  watch: ->
    @watcher or=
      wch.stream @root,
        only: ['cush.config.js']
      .on 'data', (evt) =>
        @config = evalFile(evt.path) or {}
        @bundles.forEach (bundle) ->
          bundle._invalidate true
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

    # Bundle-specific configuration
    if config = @config.bundles?[bundle.main.name]

      if typeof config.init is 'function'
        try await config.init.call bundle
        catch err
          log.error err

      if Array.isArray config.parsers
        bundle.merge 'parsers', config.parsers

      if Array.isArray config.plugins
        await bundle.use config.plugins

    # Format-specific configuration
    if fn = @config[bundle.constructor.id]
      try await fn.call bundle
      catch err
        log.error err
      return
