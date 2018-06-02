path = require 'path'
fs = require 'saxon/sync'
os = require 'os'

base = /^[./]$/

findPackage = (file) ->
  dir = path.dirname file
  loop
    return dir if fs.isFile path.join dir, 'package.json'
    break if base.test dir = path.dirname dir
  null

module.exports = findPackage
