MagicString = require '@cush/magic-string'
isObject = require 'is-object'
sorcery = require '@cush/sorcery'
cush = require 'cush'
path = require 'path'

self = exports

self.name = 'css'

self.exts = ['.css', '.scss', '.sass']

self.plugins = [
  require './plugins/sass'
  require './plugins/postcss'
]

self.mixin =

  _wrapSourceMapURL: (url) ->
    "/*# sourceMappingURL=#{url} */"

  _joinModules: ->
    result = new MagicString.Bundle

    files = []    # added files
    modules = {}  # module lookup

    addModule = (mod) =>
      return if files[mod.file.id]
      files[mod.file.id] = mod.file

      # store module by path (for source mapping)
      filename = @relative mod
      modules[filename] = mod

      code = new MagicString mod.content
      code.prepend "\n/* #{filename} */\n" if @dev
      code.trimEnd()

      # strip any `@import` statements
      mod.deps.forEach (dep) ->
        code.remove dep.start, dep.end
        addModule dep.module

      result.addSource {filename, content: code}

    addModule @main
    result = [
      content: result.toString()
      map: result.generateMap
        includeContent: false
    ]

    try @_hooks.bundle.each (hook) =>
      return if !res = await hook result[0].content, this
      return if typeof res.content isnt 'string'
      return result.unshift res if isObject res.map
      throw Error '"bundle" hook should return falsy or {content, map} object'

    catch err
      if err.line? and err.column?
        trace = sorcery.portal result,
          readFile: (filename) -> modules[filename].content
        traced = trace err.line, err.column - 1
        err.file = path.join @main.pack.root, traced.source
        err.line = traced.line
        err.column = traced.column
      throw err

    content: result[0].content
    map: sorcery result,
      getMap: (filename) -> modules[filename].map or false
      includeContent: false
