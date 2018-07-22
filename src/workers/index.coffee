path = require 'path'
log = require('lodge').debug('cush')
cp = require 'child_process'

# Pending requests
pending = {}

# Send a message and wait for a response.
requestId = 1
request = (msg) ->
  id = requestId++
  @send ['request', id, msg]
  pending[id] = req = defer()
  return req.promise

workers = do ->
  workerPath = path.join __dirname, 'worker.js'

  count = process.env.CUSH_WORKERS
  count =
    if count then parseInt count
    else require 'physical-cpu-count'

  onMessage = (msg) ->
    if handler = events[msg[0]]
    then handler msg[1], msg[2], msg[3]
    else log.warn 'Unhandled worker message:', msg

  env = Object.assign {}, process.env
  config = {env}

  inspectIdx = process.execArgv.findIndex (arg) ->
    arg.startsWith '--inspect'

  # When inspecting the main process, limit the workers to 1
  # and ensure the worker uses a different port.
  if inspectIdx isnt -1
    config.execArgv =
      execArgv = process.execArgv.slice()
    execArgv[inspectIdx] += '=9230'
    count = 1

  for i in [0...count]
    env.WORKER_ID = i + 1
    worker = cp.fork workerPath, process.argv, config
    worker.request = request
    worker.packCount = 0
    worker.on 'message', onMessage

events =

  response: (id, error, result) ->
    req = pending[id]
    delete pending[id]
    if error then req.reject error
    else req.resolve result

module.exports =

  loadBundle: (bundle) ->
    broadcast ['loadBundle', {
      id: bundle.id
      dev: bundle.dev
      root: bundle.root.path
      target: bundle.target
      config: bundle._config
      plugins: bundle._workers
      parsers: bundle.parsers
    }]

  loadAsset: (asset) ->
    worker = getWorkerForPack pack = asset.owner
    worker.request ['loadAsset', asset.name, pack.path, pack.bundle.id]

  dropPackage: (pack) ->
    if worker = pack.worker
      worker.send ['dropPackage', pack.path, pack.bundle.id]
      worker.packCount -= 1
      pack.worker = null
      return

  dropBundle: (bundle) ->
    broadcast ['dropBundle', bundle.id]

  printStats: (bundle) ->
    msg = ['printStats', bundle.id]
    for worker in workers
      await worker.request msg
    return

#
# Helpers
#

# Send a message to all workers.
broadcast = (msg) ->
  for worker in workers
    worker.send msg
  return

# Each package gets a dedicated worker to avoid loading
# and configuring any packages more than once.
getWorkerForPack = do ->

  lowestPackCount = (curr, worker) ->
    return worker if !curr or curr.packCount > worker.packCount
    return curr

  return (pack) ->
    if !worker = pack.worker
      pack.worker = worker =
        workers.reduce lowestPackCount
      worker.packCount += 1
    return worker

defer = ->
  args = null
  promise: new Promise -> args = [...arguments]
  resolve: args[0]
  reject: args[1]
