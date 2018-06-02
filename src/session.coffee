cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'
os = require 'os'

# - clock: last file change
# - packages: {packageId => {path, deps}}
#   - deps: string[]
# - bundles: {bundleId => {main, target, modules}}
#   - main: {file, imports}
#   - modules: {moduleId => {file, imports, parents}}
#     - imports: [moduleId]
#     - parents: [moduleId]
#
# • the module IDs are generated before saving
#

# 1. restore packages (read, crawl)
# 2. restore bundles (read)
# 3. restore modules (read)
# 4. check for changed modules

exports.load = ->
  seshPath = path.join os.homedir(), '.cush/session.json'
  if fs.isFile seshPath
    sesh = JSON.parse fs.readFile seshPath

    cush.clock =
  else
    cush.clock = Date.now() / 1000

exports.save = ->
