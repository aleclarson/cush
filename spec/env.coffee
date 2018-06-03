assert = require 'assert'
temp = require 'temp'
path = require 'path'
fs = require 'saxon/sync'

cush = require 'cush'
Bundle = require 'cush/lib/Bundle'
Package = require 'cush/lib/fs/Package'

env = exports

# The temporary root of all test files.
base = temp.track().mkdirSync 'cush-'

# Make sure SIGINT causes an exit event.
process.once 'SIGINT', -> process.exit()

# Tell modules they're in a test.
process.env.TEST = true

# Create a package and add it to `cush.packages`
env.makePackage = (name, data = {}) ->
  data.name ?= path.basename name
  data.version ?= '1.0.0'

  packPath = path.join base, name
  fs.mkdir packPath if name isnt ''
  fs.write packPath + '/package.json', JSON.stringify(data)
  cush.package packPath, data

env.makeBundle = (name, opts) ->
  cush.bundle path.join(base, name), opts

Package::write = (name, content) ->
  fs.mkdir path.join(@root, path.dirname name)
  fs.write path.join(@root, name), content
  @files[name] or= true
  @file name

Package::stubs = (stubs) ->
  for name in stubs
    @write name, ''
  return

Package::depend = (pack) ->
  deps = @data.dependencies ?= {}
  deps[pack.data.name] = pack.data.version
  return this

Bundle::assertMissed = (refs) ->
  i = -1
  for [mod, index] in @missed
    assert.equal @relative(mod) + ':' + mod.imports[index].id, refs[++i]
  if i + 1 < refs.length
    assert.equal undefined, refs[i + 1]
  return

Bundle::assertModules = (names) ->
  i = -1
  @_order?.forEach (mod) =>
    assert.equal @relative(mod), names[++i]
  if i + 1 < names.length
    assert.equal undefined, names[i + 1]
  return

# Reset any state.
env.resetProject = ->

  # Remove all listeners.
  cush.off '*'

  # Reset the filesystem.
  for name in fs.list base
    fs.remove path.join(base, name), true

  # Reset the bundle cache.
  cush.bundles = Object.create null

  # Clear the package cache.
  cush._resetPackages()

  # Create the main package.
  env.makePackage '', {name: 'project'}

util = require 'util'
global.inspect = (...args) ->
  val = args.pop()
  console.log ...args, util.inspect(val, false, 1, true)
