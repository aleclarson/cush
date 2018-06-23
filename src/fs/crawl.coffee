{relative} = require '../utils'
globRegex = require 'glob-regex'
noop = require 'noop'
path = require 'path'
fs = require 'fs'

# Crawls the given `root` directory, and modifies the given `files` object.
crawl = (root, files, opts = {}) ->
  only = matchGlobs opts.only
  skip =
    if opts.skip
    then matchGlobs(opts.skip)
    else noop.false

  i = -1
  dirs = [root]
  while dir = dirs[++i]

    for name in fs.readdirSync dir
      abs = path.join dir, name
      rel = path.relative root, abs
      continue if skip rel, name

      if fs.statSync(abs).isDirectory()
        dirs.push abs

      else if only rel, name
        # resolve file symlinks
        if name = follow abs, rel
          files[rel] ?= name

  return

module.exports = crawl

# paths equal to "." or ".."
# paths starting with "./" or "../"
dotRelativeRE = /^\.?\.(?:\/|$)/

# 1-deep symlinks only
follow = (abs, rel) -> try
  link = fs.readlinkSync abs

  # absolute links are ignored
  if path.isAbsolute link
    return null

  # ensure a leading ./ or ../ exists
  if !dotRelativeRE.test link
    link = './' + link

  # resolve the relative name
  relative rel, link

catch err
  if err.code is 'EINVAL'
    return true
  else throw err

matchGlobs = (globs) ->
  if !globs or !globs.length
    return noop.true

  len = globs.length
  globs = globs.map matchGlob
  return (file, name) ->
    i = -1; while ++i < len
      return true if globs[i].test(globs[i].base and name or file)

matchGlob = (glob) ->

  if glob.indexOf('/') is -1
    glob = globRegex glob
    glob.base = true
    return glob

  if glob[0] is '/'
    glob = glob.slice 1

  else if glob[0] isnt '*'
    glob = '**/' + glob

  if glob.slice(-1) is '/'
    glob += '**'

  globRegex glob
