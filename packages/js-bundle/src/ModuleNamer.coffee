
ModuleNamer = (bundle) ->
  if !bundle.dev
    return (mod) -> String(mod.file.id)

  # Resolve package names.
  packs = bundle.packages

  packIds = []
  packs.forEach (pack, i) ->
    {name, version} = pack.data
    dupe = packIds[name]
    if dupe isnt undefined
      if dupe isnt true
        packIds[name] = true
        packIds[dupe] = name + '@' + packIds[dupe].data.version
      packIds[i] = name + '@' + version
    else
      packIds[name] = i
      packIds[i] = name
    return

  return (mod) ->
    "'#{packIds[packs.indexOf mod.pack]}/#{mod.file.name}'"

module.exports = ModuleNamer
