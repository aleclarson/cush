log = require('lodge').debug('cush')

class BundleEvent
  constructor: ->
    @hooks = []
    @_next = 0

  add: (hook, priority = 0) ->
    if priority is 1
      @hooks.push hook
    else
      if priority is 0
      then @hooks.splice @_next, 0, hook
      else @hooks.unshift hook
      @_next += 1
    return hook

  emit: (...args) ->
    @hooks.forEach (hook) ->
      try hook ...args
      catch err
        log.error err

module.exports = BundleEvent
