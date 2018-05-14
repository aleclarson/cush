{loadBundles} = require './utils'
EventEmitter = require 'events'

cush = new EventEmitter
cush.config = require './config'

module.exports = cush
