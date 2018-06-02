crypto = require 'crypto'

sha256 = (data, len) ->

  hash = crypto
    .createHash 'sha256'
    .update data
    .digest 'hex'

  if typeof len is 'number'
  then hash.slice 0, len
  else hash

module.exports = sha256
