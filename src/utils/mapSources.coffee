sorcery = require '@cush/sorcery'

# Update the sourcemap of a file.
mapSources = (source, result) ->

  source.map =
    if source.map
    then sorcery [result, source],
      includeContent: false
    else result.map

  source.content = result.content
  return

module.exports = mapSources
