
defaults = [
  '/.git'
  '/.git/'
  '/node_modules/'

  '.DS_Store'        # macOS Finder metadata
  '.*.sw[a-z]', '*~' # vim temporary files

  # test files
  '__tests__/', '__mocks__/', 'spec/', 'test/', '*.test.*'
]

module.exports = (globs) ->
  defaults.concat globs or []
