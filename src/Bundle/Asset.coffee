{loadAsset} = require '../workers'
path = require 'path'

class Asset
  constructor: (@id, @name, @owner) ->
    @content = null
    @deps = null
    @map = null
    @time = 0

  path: ->
    path.join @owner.path, @name

  _load: ->
    Object.assign this, await loadAsset this

  _unload: ->
    if @content isnt null
      @content = null
      @map = null
    return

module.exports = Asset
