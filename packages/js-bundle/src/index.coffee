ModuleNamer = require './ModuleNamer'
MagicString = require 'magic-string'
sorcery = require '@cush/sorcery'
cush = require 'cush'
fs = require 'saxon/sync'

polyfills =
  require: fs.read __dirname + '/../polyfills/require.js'

self = exports

self.name = 'JavaScript'

self.exts = ['.js', '.ts', '.coffee', '.jsx', '.tsx']

self.plugins = [
  require './plugins/buble'
  require './plugins/nebu'
  # require './plugins/uglify'
]

self.mixin =

  _joinModules: ->
    {target, dev} = @opts

    result = new MagicString.Bundle

    # polyfills
    result.prepend polyfills.require + '\n'

    # global variables
    result.prepend "window.env = '#{target}';\n"
    dev and result.prepend 'window.dev = true;\n'

    # module lookup by path (relative to project root)
    modules = {}

    getModuleName = ModuleNamer this
    @files.forEach (file) =>
      mod = @modules[file.id]
      code = new MagicString mod.content

      # store module by path (for source mapping)
      filename = @relative mod
      modules[filename] = mod

      # swap out any `require` calls
      mod.deps.forEach (dep) ->
        code.overwrite dep.start, dep.end, getModuleName(dep.module)

      # wrap modules with a `__d` call
      code.trim()
      code.indent '  '
      code.prepend "/* #{filename} */\n" if dev
      code.prependRight 0, """
        __d(#{getModuleName mod}, function(module, exports) {\n
      """
      code.append '\n});\n'

      # add to the bundle
      result.addSource {filename, content: code}

    # require the main module
    result.append "\nrequire(#{getModuleName @main});"

    # create the bundle string
    result =
      content: result.toString()
      map: result.generateMap
        includeContent: false

    # trace the mappings to their original sources
    result.map = sorcery result,
      getMap: (filename) -> modules[filename].map or false
      includeContent: false

    result
