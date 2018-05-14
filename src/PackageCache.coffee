path = require 'path'
cush = require 'cush'

class PackageCache
  constructor: ->
    super()
    @_packs = Object.create null  # {'@org/foo@0.0.1' => Package}

  get: (name, version) ->
    @_packs[name + '@' + version] or null

  add: (root) ->
    if !path.isAbsolute root
      throw Error "Package root must be absolute: '#{root}'"
    pack = new Package root
    if pack.config
    pack = @find pack.name, pack.version

  find: (fn) ->
    for id, pack of @_packs
      return pack if fn pack
    null

  filter: (fn) ->
    packs = []
    for id, pack of @_packs
      packs.push pack if fn pack
    return packs

module.exports = PackageGraph
