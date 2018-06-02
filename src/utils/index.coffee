isObject = require 'is-object'

push = Function.apply.bind [].push

u = exports

u.evalFile = require './evalFile'
u.findPackage = require './findPackage'
u.lazyRequire = require './lazyRequire'
u.mapSources = require './mapSources'
u.relative = require './relative'
u.sha256 = require './sha256'
u.uhoh = require './uhoh'

u.cloneArray = (a) ->
  len = a.length
  if len > 50 then a.concat()
  else
    i = len
    b = new Array len
    b[i] = a[i] while i--
    b

u.concat = (a, b) ->
  return b unless an = a.length
  return a unless bn = b.length
  res = new Array i = an + bn
  res[i] = b[i - an] while i-- isnt an
  res[i] = a[i--] while i isnt -1
  res

u.each = (obj, fn, ctx) ->
  if obj
    for key, val of obj
      fn.call ctx, val, key
    return

u.merge = (a, b) ->

  if Array.isArray b
    push a, b
    return a

  for key, val of b

    if Array.isArray val
      if Array.isArray a[key]
        push a[key], val
        continue

    else if isObject val
      if isObject a[key]
        u.merge a[key], val
        continue

    if val isnt undefined
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
