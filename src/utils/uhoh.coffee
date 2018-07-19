uhoh = (error, code) ->

  if error.constructor is Object
    error = Object.assign new Error(error.message), error
  else
    error = new Error error
    error.code = code if code?

  Error.captureStackTrace error, uhoh
  throw error

module.exports = uhoh
