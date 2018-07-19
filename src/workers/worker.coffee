Bundle = require './Bundle'

bundles = {}

methods =

  loadBundle: (props) ->
    bundles[props.id] = new Bundle props
    return

  loadAsset: (name, root, bundleId) ->
    bundles[bundleId]._loadAsset name, root

  dropPackage: (root, bundleId) ->
    delete bundles[bundleId].packages[root]

  dropBundle: (bundleId) ->
    delete bundles[bundleId]

  printStats: (bundleId) ->
    bundles[bundleId]._printStats()

  request: (id, msg) ->
    try result = await methods[msg[0]] ...msg.slice 1
    catch err
      err = Object.assign {
        message: err.message
        stack: err.stack
      }, err
      process.send ['response', id, err]
      return
    process.send ['response', id, null, result]
    return

process.on 'message', (msg) ->
  methods[msg[0]] msg[1], msg[2], msg[3]
  return

process.on 'disconnect', ->
  process.send = -> # no-op
  return
