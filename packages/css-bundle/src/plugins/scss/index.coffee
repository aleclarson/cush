
# lazy-loaded modules
sass = null
syntax = null

# supported file extensions
exts = ['.scss', '.sass']

module.exports = ->
  @hook 'bundle', renderBundle
  @hookModules exts, (mod) =>
    sass or= require 'node-sass'
    if !syntax
      syntax = require 'postcss-scss'
      syntax.tokenize = require 'postcss-scss/lib/scss-tokenize'

    mod.ext = '.css'
    mod.syntax = syntax
    return

matchExts = (file) ->
  exts.indexOf(file.ext) >= 0

renderBundle = (input, bundle) ->
  return if !bundle.files.some matchExts
  res = sass.renderSync
    data: input
    file: ''
    outFile: 'bundle.css'
    sourceMap: true
    omitSourceMapUrl: true
  res.content = res.css.toString()
  res.map = JSON.parse res.map.toString()
  res
