tarInstall = require 'tar-install'
tarUrl = require 'tar-url'
semver = require 'semver'
path = require 'path'
cush = require 'cush'
uhoh = require './uhoh'
fs = require 'saxon/sync'

# TODO: when should packages be updated?
lazyRequire = (name, range = '*') ->
  if version = semver.valid(range) or matchVersion(name, range)
    dep = path.join cush.PACKAGE_DIR, name + '-' + version
  if !dep or !fs.exists dep
    cush.emit 'log', {type: 'install', name, range}
    if url = await tarUrl name, range
      res = await tarInstall url, cush.PACKAGE_DIR
      if res.stderr
        if cush.verbose
          console.error res.stderr
        uhoh "Failed to install: '#{name}@#{range}'"
      else dep = res.path
    else uhoh "Unknown version: '#{name}@#{range}'"
  require dep

# Try matching an existing version.
matchVersion = (name, version) ->
  try files = fs.list cush.PACKAGE_DIR
  return null if !files
  matcher = new RegExp name + '-([0-9].+)'
  matches = files
    .map (file) -> matcher.exec(file)?[1]
    .filter semver.valid
  semver.maxSatisfying matches, version

module.exports = lazyRequire
