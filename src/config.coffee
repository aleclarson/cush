config =
  exclude: [
    '/.git'
    '/.git/'
    '/node_modules/'

    '.DS_Store'        # macOS Finder metadata
    '.*.sw[a-z]', '*~' # vim temporary files

    # test files
    '__tests__/', '__mocks__/', 'spec/', 'test/', '*.test.*'
  ]

module.exports = (key, val) ->
  if arguments.length is 2
    eval "config.#{key} = val; undefined"
  else eval "config.#{key}"
