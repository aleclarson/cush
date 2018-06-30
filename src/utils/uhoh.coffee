cush = require '../index'

uhoh = (err) ->
  if err.constructor is Object
    err = Object.assign new Error(err.message), err
  else err = new Error err
  Error.captureStackTrace err, uhoh
  cush.emit 'error', err
  throw err

module.exports = uhoh
