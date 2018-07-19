
returnCallSites = (e, stack) ->
  return stack

getCallSite = (offset = 0) ->
  orig = Error.prepareStackTrace
  Error.prepareStackTrace = returnCallSites
  callsite = Error().stack[1 + offset]
  Error.prepareStackTrace = orig
  return callsite

module.exports = getCallSite
