# cush-plugin-uglify-js

Minify each module using [uglify-js](https://github.com/mishoo/UglifyJS2).

By default, minification occurs in both development *and* production modes.
This way, you'll usually be the first to experience any rare bugs caused by
minification, resulting in a better user experience!

The default settings for minification were carefully selected to avoid losing
information that's necessary for useful source maps.

## Configuration

The `uglify` setting can be configured by your `cush.config.js` module.
Set it to false to disable minification, or provide [uglify options][3]
to customize how modules are minified.

[3]: https://github.com/mishoo/UglifyJS2#minify-options

```js
// Inline single-use variables and functions, but make source maps less useful.
this.set('uglify', {
  compress: {
    reduce_vars: false,
    reduce_funcs: false,
    collapse_vars: false,
  }
});
```
