EventEmitter = require 'events'
path = require 'path'
os = require 'os'

cush = exports
cush.config = require './config'
cush.verbose = process.env.VERBOSE isnt ''

# Cache directories
cush.BASE_DIR = path.join os.homedir(), '.cush'
cush.BUNDLE_DIR = path.join cush.BASE_DIR, 'bundles'
cush.PACKAGE_DIR = path.join cush.BASE_DIR, 'packages'

# Global events
events = new EventEmitter
cush.emit = events.emit.bind events
cush.on = events.on.bind events
cush.off = (name, listener) ->
  if name is '*'
    events.removeAllListeners()
  else events.removeListener name, listener

# Prevent warnings from going unseen.
cush.on 'warning', ->
  if events.listenerCount('warning') is 1
    console.warn.apply console, arguments
  return

cush.on 'error', ->
  if events.listenerCount('error') is 1
    console.error.apply console, arguments
  return
