BundleEvent = require './Event'
getCallSite = require '../utils/getCallSite'
merge = require '../utils/merge'

# This mixin provides the methods used by plugins.
# These methods are available both in and out of workers.
mixin =

  has: (path) ->
    if typeof path == 'string'
      path = path.split '.'

    obj = @_config
    last = path.length - 1
    for i in [0 ... last]
      obj = obj[path[i]]
      if !obj or obj.constructor != Object
        return false

    return obj[path[last]] != undefined

  get: (path, elseVal) ->
    if typeof path == 'string'
      path = path.split '.'

    obj = @_config
    last = path.length - 1
    for i in [0 ... last]
      prev = obj
      obj = prev[path[i]]
      break if !obj?
      if obj.constructor != Object
        path = path.slice(0, i + 1).join '.'
        throw TypeError "'#{path}' is not an object"

    val = obj and obj[path[last]]
    if arguments.length == 2
      return val ? setPath obj or prev, path.slice(i), elseVal
    return val

  set: (path, val) ->
    if typeof path == 'string'
      path = path.split '.'
    setPath @_config, path, val
    return this

  merge: (path, val) ->
    if arguments.length is 2
      if typeof path == 'string'
        path = path.split '.'
      obj = @get path
    else
      obj = @_config
      val = path

    if obj and obj.constructor == val.constructor
      merge obj, val
    else if arguments.length is 2
      setPath @_config, path, val
    else
      throw TypeError 'Cannot merge that value: ' + (JSON.stringify(value) or Object::toString.call value)
    return this

  hook: (id, hook) ->
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    if typeof hook == 'function'
      hook.source or= @_getSource(1)
      event.add hook
      return this
    return event

  hookLeft: (id, hook) ->
    if typeof hook != 'function'
      throw TypeError '`hook` must be a function'
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    hook.source or= @_getSource(1)
    event.add hook, -1
    return this

  hookRight: (id, hook) ->
    if typeof hook != 'function'
      throw TypeError '`hook` must be a function'
    if !event = @_events[id]
      @_events[id] = event = new BundleEvent
    hook.source or= @_getSource(1)
    event.add hook, 1
    return this

  _getSource: (offset = 0) ->
    frame = getCallSite 1 + offset
    path: frame.getFileName()
    line: frame.getLineNumber()

module.exports = (ctr) ->
  Object.assign ctr.prototype, mixin

setPath = (obj, path, val) ->

  last = path.length - 1
  for i in [0 ... last]
    prev = obj
    obj = prev[path[i]]
    if !obj?
      prev[path[i]] = obj = {}
    else if obj.constructor != Object
      path = path.slice(0, i + 1).join '.'
      throw TypeError "'#{path}' is not an object"

  obj[path[last]] = val
  return val
