relative = require '@cush/relative'
recrawl = require 'recrawl'
path = require 'path'
fs = require 'fs'

crawl = (root, files, opts) ->
  recrawl(opts) root, (file) ->
    return if files[file]

    if target = follow path.join(root, file)
      target = path.relative root, target
      return if target[0] is '.'

    files[file] = target or true
    return

module.exports = crawl

# paths equal to "." or ".."
# paths starting with "./" or "../"
dotRelativeRE = /^\.?\.(?:\/|$)/

# 1-deep symlinks only
follow = (link) -> try
  target = fs.readlinkSync link

  # absolute links are ignored
  if path.isAbsolute target
    return null

  # ensure a leading ./ or ../ exists
  if !dotRelativeRE.test target
    target = './' + target

  # resolve the relative name
  relative link, target

catch err
  if err.code is 'EINVAL'
    return null
  else throw err
