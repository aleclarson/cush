# Plugins

This document describes how to use and create a plugin.

Plugins are applied on a per-bundle basis.

## Using a plugin

Plugins can be strings, functions, objects, or arrays. Strings are used to resolve the filename of a plugin. You can omit `cush-plugin-` from the string and it will be added for you. When a filename cannot be resolved, the plugin is installed from NPM into `~/.cush/packages` automatically. It's recommended you install plugins manually, because [auto-upgrading](https://github.com/aleclarson/cush/issues/28) is not yet supported. Plugin arrays can contain plugin arrays.

The `plugins` option of `cush.bundle()` can be used to define plugins when creating a bundle. Its an array whose values can be the same as what `Bundle#use` accepts.

The `Bundle#use` method can be used to define plugins after a bundle has been created. This allows plugins to define their own plugins, too. You can pass a single plugin or an array of plugins.

## Creating a plugin

If you know the API for `cush.config.js` module, you know the API for plugins. That's because they use the same API. 😄

Your plugin's name should begin with `cush-plugin-`, but it's not required.

You must export a function or an object. The function is called in the main process whenever a bundle is being configured, which occurs on the first build and after `cush.config.js` changes. The function has access to the `Bundle` object as `this`.

## Worker plugins

Your plugin can extend the worker farm by exposing a `worker` property on its exported object/function. This property must be a string, which is used to resolve the filename of a worker module.
  
Your worker module must export a function that will be called whenever a bundle is being configured, which occurs on the first build and after `cush.config.js` changes. The function has access to the `Bundle` object as `this`, but the bundle is *not* the same as in the main process.

[Learn more](./workers.md) about workers.

## Transforming an asset

To transform an asset, you need to call `Bundle#transform` while in a worker.

```js
// index.js
exports.worker = require.resolve('./worker');

// worker.js
module.exports = function() {
  this.transform(['.es6', '.es6.js'], async (asset, pack) => {
    const result = await transformES6(asset.content);

    // Return the content and source map if no errors occurred.
    return {
      content: result.js,
      map: result.v3SourceMap,
    };
  });
};
```

## Custom hooks

Your plugin can provide its own hooks for others to use.

```js
const event = this.hook('foo');
event.emit(1, 2, 3);
```
