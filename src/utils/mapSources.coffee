sorcery = require 'sorcery'

# Update the sourcemap of a file.
mapSources = (file, result) ->

  file.map =
    if file.map
    then sorcery [result, file], includeContent: false
    else result.map

  file.content = result.content
  return

module.exports = mapSources
