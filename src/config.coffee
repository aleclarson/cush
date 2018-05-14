config =
  exclude: [
    '**/node_modules/**' # dependencies
    '.*.sw[a-z]', '*~'   # vim temporary files
    '.DS_Store'          # macOS Finder metadata
  ]

module.exports = (key, val) ->
  if arguments.length is 2
    eval "config.#{key} = val; undefined"
  else eval "config.#{key}"
