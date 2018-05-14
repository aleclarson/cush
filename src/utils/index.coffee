isObject = require 'is-object'
crypto = require 'crypto'

push = Function.apply.bind [].push

u = exports

u.findPackage = require './findPackage'
u.lazyRequire = require './lazyRequire'

u.sha256 = (data, len) ->

  hash = crypto
    .createHash 'sha256'
    .update data
    .digest 'hex'

  if typeof len is 'number'
  then hash.slice 0, len
  else hash

u.cloneArray = (a) ->
  len = a.length
  if len > 50 then a.concat()
  else
    i = len
    b = new Array len
    b[i] = a[i] while i--
    b

u.deepMerge = (a, b) ->
  for key, val of b

    if Array.isArray val
      if Array.isArray a[key]
        push a[key], val
        continue

    else if isObject val
      if isObject a[key]
        u.deepMerge a[key], val
        continue

    a[key] = val
  return a

# Arrays are only shallow cloned.
u.cloneObject = (obj) ->
  res = {}
  for key, val of obj
    res[key] = Array.isArray(val) and u.cloneArray(val) or
      isObject(val) and u.cloneObject(val) or val
  return res

# Arrays are only shallow cloned.
u.mergeDefaults = (a, b) ->
  for key, val of b
    if a[key] is undefined
      a[key] = Array.isArray(val) and u.cloneArray(val) or
        isObject(val) and u.cloneObject(val) or val
    else if isObject val
      u.mergeDefaults a[key], val
  return a
