cush = require 'cush'
path = require 'path'
fs = require 'saxon'

loadFile = (file, pack) ->

  # Read the file.
  file.content ?= await fs.read pack.resolve(file)

  # Transform the file.
  try while true
    {ext} = file
    if transform = cush.transformers[ext]
      await transform file, pack
      break if ext is file.ext
    else break
  catch err
    cush.emit 'error',
      message: 'Failed to transform a file'
      error: err
      file: pack.resolve file

  return file

module.exports = loadFile
