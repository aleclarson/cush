{mapSources} = require '../../utils'
sucrase = require('@cush/sucrase').transform
cush = require 'cush'
path = require 'path'

tsRE = /^\.tsx?$/
jsxRE = /^\.(?:t|j)sx$/

# TODO: customizable `jsxPragma`
transform = (file, pack) ->
  return if file._sucrase is file.time

  tforms = ['imports']

  if jsxRE.test file.ext
    tforms.push 'jsx'

  if tsRE.test file.ext
    tforms.push 'typescript'

  else if isFlow pack
    tforms.push 'flow'

  filename = pack.resolve file
  try res = sucrase file.content,
    filePath: filename
    transforms: tforms
    sourceMapOptions: {}
    enableLegacyBabel5ModuleInterop: true

  catch err
    cush.emit 'warning',
      message: 'sucrase threw an error: ' +
        (cush.verbose and err.stack or err.message)
      file: filename
    return

  mapSources file, res

  file.ext = '.js'
  file._sucrase = file.time
  return

isFlow = (pack) ->
  deps = pack.data.devDependencies
  Boolean deps and deps['flow-bin']

exports['.js'] =
exports['.ts'] =
exports['.jsx'] =
exports['.tsx'] = transform
