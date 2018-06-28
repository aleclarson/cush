relative = require '@cush/relative'
recrawl = require 'recrawl'
path = require 'path'
fs = require 'fs'

crawl = (root, files, opts) ->
  recrawl(opts) root, (file) ->
    files[file] = follow(file) or true
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
