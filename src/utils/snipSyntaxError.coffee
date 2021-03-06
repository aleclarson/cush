util = require 'util'
log = require('lodge').debug('cush')

screenWidth = process.stdout.columns - 2

inspect = (err) ->
  util.inspect {message: err.message, ...err},
    compact: true
    colors: true

# `err.line` must be one-based
# `err.column` must be zero-based
snipSyntaxError = (content, err) ->

  if !code = content.split('\n')[err.line - 1]
    throw RangeError util.format 'Invalid line: %s', inspect(err)

  line = err.line + ': '
  column = err.column - code.length

  code = code.trimLeft()
  column += length = code.length

  maxLength = screenWidth - line.length
  if length > maxLength

    # Clip the left side.
    start = 0
    if err.column > maxLength
      start = code.lastIndexOf ' ', err.column
      start = column - 3 if start is -1
      column += 3 - start
      length -= start
      maxLength -= 3

    # Clip the right side.
    if length > maxLength
      length = maxLength - 3
      end = start + length

    # Ensure all available space is used.
    else if start and length < maxLength
      length = maxLength
      column += start
      column -= start = code.length - length

    code = code.slice start, end
    code = log.coal('...') + code if start
    code += log.coal('...') if end

  column = Math.max column + line.length, line.length
  if column > screenWidth
    throw RangeError util.format 'Invalid column: %O', inspect(err)

  return """
    #{log.red line}#{code}
    #{' '.repeat column}#{log.red '^'}
  """

module.exports = snipSyntaxError
