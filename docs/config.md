# cush.config.js

This document describes the `cush.config.js` module, which is used to configure the bundles of a project.

## `bundles` object

The `bundles` object defines options for bundles. 

Each key is the path to a bundle's main module (relative to the project root).

Each value is an [options][opts] object.

[opts]: ./fs.md#creating-a-bundle

```js
exports.bundles = {
  'src/index.js': {
    format: require('foo-bundle'),
    plugins: [],
    init() {
      console.log(this); // [object Bundle]
    }
  }
};
```

## Format customization

You can customize bundles that use a specific [bundle format](./formats.md).

```js
const JSBundle = require('js-bundle');

exports[JSBundle.id] = function() {
  console.log(this); // [object Bundle]
};
```

If you know the format `id`, you can avoid importing it.

```js
exports.js = function() {};
```

Format functions use the same API as [plugins](./plugins.md).

## Config methods

These methods are for accessing and mutating bundle configuration.

The `key` argument can use dot-notation.

#### `get(key: string): ?any`

Get a value from the config object.

Returns `undefined` when the key does not exist.

Throws if the key tries to access a defined non-object.

#### `set(key: string, value: any): this`

Set a property in the config object.

Throws if the key tries to mutate a defined non-object.

#### `merge(key: string, values: Object|Array): this`

Merge `values` into a property.

When the existing value is not the same type as the given `values`, it is overwritten. The given object is no longer yours at this point.

Otherwise, the given `values` are merged into the existing value. When `values` is an array, it's concatenated to the end of the existing array. When `values` is an object, it's deeply merged into the existing object.

#### `merge(values: Object): this`

Deeply merge `values` into the top-level config.
