Emitter = require '@cush/events'
path = require 'path'
os = require 'os'

cush = new Emitter

# Cache directories
cush.BASE_DIR = path.join os.homedir(), '.cush'
cush.BUNDLE_DIR = path.join cush.BASE_DIR, 'bundles'
cush.PACKAGE_DIR = path.join cush.BASE_DIR, 'packages'

log = require('lodge').debug('cush')
require('elaps').log or= log

# Prevent warnings from going unseen.
cush.on 'warning', (...args) ->
  if cush.listenerCount('warning') is 1
    log.warn ...args
  return

cush.on 'error', (...args) ->
  if cush.listenerCount('error') is 1
    log.error ...args
  return

module.exports = cush
