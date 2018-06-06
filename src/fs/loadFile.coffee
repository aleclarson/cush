cush = require 'cush'
path = require 'path'
fs = require 'saxon'

loadFile = (file, pack) ->

  # Read the file.
  file.content ?= await fs.read path.join(pack.root, file.name)

  # Transform the file.
  try while true
    {ext} = file
    if transform = cush.transformers[ext]
      await transform file, pack
      break if ext is file.ext
    else break
  catch err
    cush.emit 'error', err

  return file

module.exports = loadFile
