env = require './env'
tp = require 'testpass'

bun = null
proj = null

init = ->
  proj = env.resetProject()
  proj.stubs ['index.js']
  bun = env.makeBundle 'index.js', target: 'web'

cleanup = ->
  bun?.destroy()

tp.afterEach cleanup

tp.group 'relative:', ->
  tp.beforeEach init
  tp.afterEach cleanup

  tp.test 'with an extension', (t) ->
    proj.write 'index.js', '''
      require('./taco.js')
    '''
    proj.stubs ['taco.js']
    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'taco.js']

  tp.test 'without an extension', (t) ->
    proj.write 'index.js', '''
      require('./taco')
    '''
    proj.stubs ['taco.js']

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'taco.js']

  tp.test 'target-specific files are preferred', (t) ->
    proj.write 'index.js', '''
      require('./taco.js') // with extension
      require('./pasta')   // no extension
    '''
    proj.stubs [
      'taco.js', 'taco.web.js'
      'pasta.js', 'pasta.web.js'
    ]

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'taco.web.js', 'pasta.web.js']

  tp.test 'path can be a directory', (t) ->
    proj.write 'index.js', '''
      require('./utils')
    '''
    proj.stubs ['utils/index.js']

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'utils/index.js']

  tp.test 'files are preferred over directories', (t) ->
    proj.write 'index.js', '''
      require('./utils')
    '''
    proj.stubs ['utils/index.js', 'utils.js']

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'utils.js']

  tp.test 'parent path [.]', (t) ->
    proj.write 'index.js', '''
      require('./foo')
    '''
    proj.write 'foo.js', '''
      require('.')
    '''

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'foo.js']

  tp.test 'grand-parent path [..]', (t) ->
    proj.write 'index.js', '''
      require('./foo/bar')
    '''
    proj.write 'foo/bar.js', '''
      require('..')
    '''

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'foo/bar.js']

  tp.test 'great grand-parent path [../..]', (t) ->
    proj.write 'index.js', '''
      require('./foo/bar/bin')
    '''
    proj.write 'foo/bar/bin.js', '''
      require('../..')
    '''

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'foo/bar/bin.js']

  tp.test 'uncle path [../foo]', (t) ->
    proj.write 'index.js', '''
      require('./foo/bar')
    '''
    proj.write 'foo/bar.js', '''
      require('../bin')
    '''
    proj.write 'bin/index.js', ''

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'foo/bar.js', 'bin/index.js']

  tp.test 'module imports the same file twice', (t) ->
    proj.write 'index.js', '''
      require('./potato')
      require('./potato')
    '''
    proj.stubs ['potato.js']

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'potato.js']

  tp.test 'two modules import the same file', (t) ->
    proj.write 'index.js', '''
      require('./sofa')
      require('./chair')
    '''
    proj.stubs ['chair.js']
    proj.write 'sofa.js', '''
      require('./chair')
    '''

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'sofa.js', 'chair.js']

tp.group 'node_modules:', ->
  tp.beforeEach init
  tp.afterEach cleanup

  # default to "./index" when 'main' field is undefined
  tp.test 'default module', (t) ->
    proj.write 'index.js', '''
      require('beluga')
    '''

    dep = env.makePackage 'node_modules/beluga'
    dep.stubs ['index.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'node_modules/beluga/index.js']

  tp.test 'main module', (t) ->
    proj.write 'index.js', '''
      require('beluga')
      require('walrus')
    '''

    # main with leading ./
    dep = env.makePackage 'node_modules/beluga'
    dep.data.main = './lib/index'
    dep.stubs ['lib/index.coffee']
    proj.depend dep

    # main without leading ./
    dep = env.makePackage 'node_modules/walrus'
    dep.data.main = 'walrus'
    dep.stubs ['walrus.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed []
    bun.assertModules [
      'index.js'
      'node_modules/beluga/lib/index.coffee'
      'node_modules/walrus/walrus.js'
    ]

  tp.test 'child module', (t) ->
    proj.write 'index.js', '''
      require('beluga/utils')
    '''

    dep = env.makePackage 'node_modules/beluga'
    dep.stubs ['index.js', 'utils.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'node_modules/beluga/utils.js']

  tp.test 'scoped package', (t) ->
    proj.write 'index.js', '''
      require('@ocean/fish')
    '''

    dep = env.makePackage 'node_modules/@ocean/fish',
      name: '@ocean/fish'
    dep.stubs ['index.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'node_modules/@ocean/fish/index.js']

  tp.test 'child of scoped package', (t) ->
    proj.write 'index.js', '''
      require('@ocean/fish/utils')
    '''

    dep = env.makePackage 'node_modules/@ocean/fish',
      name: '@ocean/fish'
    dep.stubs ['index.js', 'utils.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed []
    bun.assertModules ['index.js', 'node_modules/@ocean/fish/utils.js']

  tp.test 'packages not depended on', (t) ->
    proj.write 'index.js', '''
      require('shark')
      require('tuna')
      require('salmon')
    '''

    # this package should still be resolved.
    dep = env.makePackage 'node_modules/tuna'
    dep.stubs ['index.js']
    proj.depend dep

    await bun.read()
    bun.assertMissed ['index.js:shark', 'index.js:salmon']
    bun.assertModules []

  tp.test 'package not installed', (t) ->
    proj.write 'index.js', '''
      require('tuna')
    '''
    # exists in 'dependencies' field, but not the "node_modules" directory.
    proj.data.dependencies = tuna: '*'

    await bun.read()
    bun.assertMissed ['index.js:tuna']
    bun.assertModules []

  tp.test 'two packages depend on different versions', (t) ->
    proj.write 'index.js', '''
      require('tuna')
      require('spam')
    '''

    # versions in 'dependencies' are ignored
    proj.data.dependencies =
      tuna: '*'
      spam: '*'

    tuna1 = env.makePackage 'node_modules/tuna'
    tuna1.stubs ['index.js']

    spam = env.makePackage 'node_modules/spam'
    spam.data.dependencies = tuna: '*'
    spam.write 'index.js', '''
      require('tuna')
    '''

    tuna2 = env.makePackage 'node_modules/spam/node_modules/tuna',
      version: '1.0.1'
    tuna2.stubs ['index.js']

    await bun.read()
    bun.assertMissed []
    bun.assertModules [
      'index.js'
      'node_modules/tuna/index.js'
      'node_modules/spam/index.js'
      'node_modules/spam/node_modules/tuna/index.js'
    ]

tp.test 'two packages with the same name/version', (t) ->
  env.resetProject()
  pack = env.makePackage 'node_modules/tuna'
  t.eq pack, env.makePackage 'node_modules/foo/node_modules/tuna'

tp.test '.coffee modules', (t) ->
  proj = env.resetProject()
  proj.data.devDependencies = coffeescript: '*'
  proj.write 'index.coffee', '''
    require './taco'
  '''
  proj.stubs ['taco.coffee']

  bun = env.makeBundle 'index.coffee', target: 'web'
  await bun.read()
  bun.assertMissed []
  bun.assertModules ['index.coffee', 'taco.coffee']

tp.test ''

tp.group 'rebuild:', ->
  cush = require 'cush'

  tp.test 'on module change', (t) ->
    proj = env.resetProject()
    proj.write 'index.js', ''

    t.async()
    await wait 1  # avoid file events from setup above

    bun = env.makeBundle 'index.js', target: 'web'
    p1 = bun.read()

    # Change the mtime.
    proj.write 'index.js', ''
    next = ->
      t.eq bun.valid, true
      t.eq p1, bun.read()

      # Change the content.
      proj.write 'index.js', 'a'
      next = ->
        t.eq bun.valid, false
        t.ne p1, p2 = bun.read()

        # Further changes are batched.
        proj.write 'index.js', 'b'
        next = ->
          t.eq p2, bun.read()
          t.done()

    cush.on 'change', (file) ->
      next() if file.name is 'index.js'

  # tp.test 'on missing dependency', ->

wait = (secs) ->
  new Promise (resolve) ->
    setTimeout resolve, secs * 1000
