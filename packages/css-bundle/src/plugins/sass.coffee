{lazyRequire} = require 'cush/utils'

sass = null
syntax = null

module.exports = (bundle) ->
  sass ?= await lazyRequire 'node-sass'
  syntax ?= await lazyRequire 'postcss-scss'

  bundle.postcss.syntax = syntax
  bundle.hook 'bundle', transform
  return

transform = (opts, done) ->
  sass.render {
    data: opts.data
    file: opts.file
    outFile: opts.file
    sourceMap: true
    omitSourceMapUrl: true
  }, (err, res) ->
    if err
    then done err
    else done null,
      data: res.css.toString()
      map: res.map.toString()
