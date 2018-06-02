cush = require 'cush'
path = require 'path'
fs = require 'saxon'

loadFile = (file, pack) ->

  # Read the file.
  if file.content is null
    file.content = await fs.read path.join(pack.root, file.name)
    file.time = Date.now()

  # Transform the file.
  while true
    {ext} = file
    if transform = cush.transformers[ext]
      await transform file, pack
      break if ext is file.ext
    else break

  return file

module.exports = loadFile
