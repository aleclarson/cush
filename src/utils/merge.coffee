
push = Function.apply.bind [].push
isObject = (val) -> val? and val.constructor == Object

merge = (a, b) ->

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

    if val != undefined
      a[key] = val

  return a

module.exports = merge
