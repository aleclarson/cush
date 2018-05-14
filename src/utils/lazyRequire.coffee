tarInstall = require 'tar-install'
tarUrl = require 'tar-url'
path = require 'path'
cush = require 'cush'
fs = require 'fsx'
os = require 'os'

PACKAGE_DIR = path.join os.homedir(), '.cush/packages'

# TODO: when should packages be updated?
lazyRequire = (name) ->
  dep = path.join PACKAGE_DIR, name
  try require.resolve dep
  catch e
    cush.emit 'log', {type: 'installing', name}
    res = await tarInstall (await tarUrl name), PACKAGE_DIR
    fs.writeLink dep, res.path
  require dep

module.exports = lazyRequire
