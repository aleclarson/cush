ModuleNamer = require './ModuleNamer'
MagicString = require 'magic-string'
cush = require 'cush'
fs = require 'saxon/sync'

polyfills =
  require: fs.read __dirname + '/../polyfills/require.js'

self = exports

self.type = 'js'

self.exts = ['.js', '.ts', '.coffee', '.jsx', '.tsx']

self.plugins = [
  # require './plugins/buble'
  require './plugins/nebu'
  # require './plugins/uglify'
]

self.mixin =

  _joinModules: ->
    {target, dev} = @opts

    result = new MagicString.Bundle

    # polyfills
    result.prepend polyfills.require

    # global variables
    result.prepend "window.env = '#{target}';\n"
    dev and result.prepend 'window.dev = true;\n'

    getModuleName = ModuleNamer this
    @files.forEach (file) =>
      mod = @modules[file.id]
      filename = @relative mod
      str = new MagicString mod.content

      # swap out any `require` calls
      mod.deps.forEach (dep) ->
        str.overwrite dep.start, dep.end, getModuleName(dep.module)

      # wrap modules with a `__d` call
      str.trim()
      str.indent '  '
      str.prepend "\n/* #{filename} */\n" if dev
      str.prependRight 0, """
        __d(#{getModuleName mod}, function(module, exports) {\n
      """
      str.append '\n});'

      # add to the bundle
      result.addSource {filename, content: str}

    @map = result.generateMap
      includeContent: dev

    # dev bundles use inline sourcemaps
    dev and result.append '\n\n//# sourceMappingURL=' + @map.toUrl()

    result.toString()
