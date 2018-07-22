# Bundle formats

This document explains bundle formats and how to make your own.

The format of a bundle determines:
- how assets are concatenated
- which extensions are implicit
- the default plugins

These formats are available by default:
- [js-bundle](https://github.com/cushJS/js-bundle)
- [css-bundle](https://github.com/cushJS/css-bundle)

The `format` option of `cush.bundle()` can be used to explicitly choose the bundle format. It must be a function that takes the bundle options and returns a `Bundle` object.

When the `format` option is undefined, Cush tries to resolve the format by looking for a format whose `exts` array contains the main module's extension.

If you use a third-party bundle format and want implicit resolution, you can add the format to `cush.formats`, using its `id` class property as the key.

```js
const FooBundle = require('foo-bundle');

cush.formats[FooBundle.id] = FooBundle;
```

The `id` of a format can be used in `cush.config.js` to customize bundles of that format.

```js
const FooBundle = require('foo-bundle');

exports[FooBundle.id] = function() {
  this.hook('asset', console.log);
};
```

&nbsp;

## Making your own

Custom formats must export a class that extends the `cush.Bundle` class.

### Class Properties

#### `id: string`

Your format's unique identifier (short, camel case, and first letter lowercase).

#### `exts: ?string[]`

Extensions used to resolve a dependency when no extension exists in a file reference. Also used to resolve the format of a bundle when no format is explicitly defined.

*Note:* Values must start with a period.

#### `plugins: ?(string|Function|Object)[]`

The list of default plugins, used by every bundle of this format.

The values can be the same as what `Bundle#use` accepts.

These plugins run before any user-defined plugins by default.

&nbsp;

### Methods

#### `async _concat(assets: Asset[], packages: Package[]): string`

Returns the string of concatenated assets.

The `assets` and `packages` array are in order of appearance.

**Must override this.**

#### `_wrapSourceMapURL(url: string): string`

Returns the `sourceMappingURL=` comment appended to the result of `_concat`.

**Must override this.**

#### `_getInitialConfig(): Object`

Create the initial `_config` object (used by `get`, `set`, and `merge`).

This is called before any plugins are loaded.

*Note:* Always call `super` in this method.

#### `_onConfigure(): void`

Do whatever after all plugins have been loaded.

*Note:* Always call `super` in this method.
