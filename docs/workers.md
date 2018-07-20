# Worker farm

The worker farm creates a child process for each CPU core on your machine. You can override this by exporting the `CUSH_WORKERS` environment variable.

Access the worker farm with `require('cush/lib/workers')`. In the future, plugins will be able to add methods to this object. For now, plugins can only extend the `loadAsset` method, which you should never call manually.

&nbsp;

## `Bundle` class

Bundles in a worker context use a different class than the main process.

### Properties

### `id: string`

The bundle identifier.

### `dev: boolean`

Equals `true` if in development mode.

### `root: string`

The absolute path to the bundle's root directory.

### `target: string`

The target platform.

### `packages: Object`

When multiple workers exist, this won't contain all packages used by the bundle, because packages are secluded to a single worker.

&nbsp;

### Methods

[Config methods](./config.md#config-methods) and [hook methods](#./hooks.md) are available.

These methods are also available:

### `relative(path: string): string`

Returns the path relative to `this.root`.

### `transform(exts: string|string[], fn: Function): void`

Hook into one or many `asset.[ext]` events.

&nbsp;

### Hooks

### `package(pack: Object)`

Called when a package is first used. Perfect time for plugins to do package-specific initialization.

Hooks are run in parallel and can be asynchronous.

### `asset.[ext](asset: Asset, pack: Object)`

Called after the `package` hook. Perfect time for plugins to transform an asset.

For example, `asset.js` hooks are always passed Javascript assets.

Hooks are run in order and can be asynchronous. They can return an `{content, map}` object to update an asset. The returned source map is blended into the previous source map, if one exists.

Hook errors halt any further loading of the asset.

Hooks may change the `ext` of the asset, which will skip any remaining hooks of the same extension.

### `parse.[ext](asset: Asset, pack: Object)`

Called after all `asset.[ext]` hooks. Perfect time for plugins to parse dependencies.

Hooks are run in order and can be asynchronous.

At this point, the asset is in its final form.

### `asset(asset: Asset, pack: Object)`

Called after all `parse.[ext]` hooks.

Hooks are run in order and can be asynchronous.

At this point, the asset is in its final form.

&nbsp;

## Package objects

When in a worker, packages are objects loaded from a `package.json` module. So you can assume properties like `name` and `version` will exist.

Every package has its `path` property set to the package directory that contains the `package.json` module.

Packages are bound to a single worker. This lets plugins store metadata on package objects without the risk of sharding.

&nbsp;

## Asset objects

Assets only exist while being loaded and should never be cached by plugins.

### Properties

### `path: string`

The absolute file path.

### `ext: string`

The file extension. May be mutated by plugins.

### `content: string`

The current file content. Not guaranteed to be the actual file content, because plugins are allowed to mutate this property. Changes to this property are *not* persisted to disk.

### `deps: ?Object[]`

The parsed dependencies. Always equals `null` until after the `parse` hooks are triggered, which occurs after the `asset` hooks. Even then, this property may still equal `null` if no parser is found.

The values are `{ref, start, end, asset}` objects.

### `map: ?Object`

The current source map. Plugins are allowed to mutate this property.

Its value is usually an object from [@cush/sorcery](https://www.npmjs.com/package/@cush/sorcery).
