{portal} = require '@cush/sorcery'

ErrorTracer = (sources, options) ->
  trace = portal sources, options
  return (err, source) ->

    if !err.column?
      err.column = err.col or 0
      delete err.col

    if !err.filename?
      err.filename = err.file
      delete err.file

    if !traced = trace err.line, err.column - 1
      err.filename = source or null
      return

    err.line = traced.line
    err.column = traced.column
    err.filename = traced.source
    return

module.exports = ErrorTracer
