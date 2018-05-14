cush = require 'cush'
path = require 'path'
fs = require 'fsx'
os = require 'os'

exports.load = ->
  seshPath = path.join os.homedir(), '.cush/session.json'
  if fs.isFile seshPath
    sesh = JSON.parse fs.readFile seshPath

    cush.clock =
  else
    cush.clock = Date.now() / 1000
