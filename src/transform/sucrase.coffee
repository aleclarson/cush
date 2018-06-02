t = require('elapse')('load sucrase')
sucrase = require('sucrase').transform
t.stop()

path = require 'path'

tsRE = /^\.tsx?$/
jsxRE = /^\.(?:t|j)sx$/

# TODO: customizable `jsxPragma`
transform = (file, pack) ->
  return if file._sucrase is file.time

  tforms = []

  if /\bimport\b/.test file.content
    tforms.push 'imports'

  if jsxRE.test file.ext
    tforms.push 'jsx'

  if tsRE.test file.ext
    tforms.push 'typescript'

  else if isFlow pack
    tforms.push 'flow'

  if !tforms.length
    return

  start = process.hrtime()

  file.ext = '.js'
  file.content =
    sucrase file.content,
      filePath: path.join(pack.root, file.name)
      transforms: tforms

  [sec, nano] = process.hrtime start
  elapsed = sec * 1e3 + nano * 1e-6
  console.log '[sucrase] ' + elapsed + 'ms => ' + pack.data.name + '/' + file.name

  file._sucrase = file.time
  return

isFlow = (pack) ->
  deps = pack.data.devDependencies
  Boolean deps and deps['flow-bin']

exports['.js'] =
exports['.ts'] =
exports['.jsx'] =
exports['.tsx'] = transform
