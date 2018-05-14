path = require 'path'
fs = require 'fsx'
os = require 'os'

HOME = os.homedir()

findPackage = (file) ->
  dir = path.dirname file
  loop
    return dir if fs.isFile path.join dir, 'package.json'
    break if (dir = path.dirname dir) is HOME
  null

module.exports = findPackage
