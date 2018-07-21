knownExts = require '@cush/known-exts'

extRegex = (...exts) ->
  exts = knownExts.concat ...exts
  exts = Array.from(new Set exts).sort().map (ext) -> ext.slice 1
  exts = exts.join('|').replace /\./g, '\\.'
  return new RegExp "\\.(#{exts})$"

module.exports = extRegex
