# Bundles, packages, assets, oh my!

Everything mentioned in this document is *not* applicable to workers.

### Creating a bundle

```js
const bundle = cush.bundle(main, options);
```

Available options are:
- `dev: ?boolean`
- `target: string`
- `plugins: ?(string|Function|Object)[]`
- `parsers: ?string[]`
- `format: ?Function`

The `dev` option is used by plugins and formats. Your `cush.config.js` module may even use it. The default value is `false`, which indicates a "production" bundle should be generated.

The `target` is required. Common values are `web`, `ios`, and `android`.

The `plugins` option is identical to calling `Bundle#use` with the same value. [Learn more](./plugins.md#using-a-plugin)

The `parsers` option is an array of filenames that are imported in all workers. [Learn more](./workers.md#hooks-parse)

The `format` option is explained on [this page.](./formats.md)

&nbsp;

## `Bundle` class

```js
require('cush/lib/Bundle')
```

### Properties

### `id: string`

The unique identifier. Generated from a hash of the main module's absolute path. The target is attached to the end, as well as `.dev` if the `dev` option is true.

### `dev: boolean`

*No description*

### `root: Package`

The package containing the main module.

### `main: Asset`

The main module

### `target: string`

The target platform. (eg: `web`)

### `assets: Asset[]`

The assets used in the bundle, in order of appearance.

### `packages: Object`

The packages used in the bundle, in order of appearance.

### `plugins: Array`

The array of plugins that you passed to `cush.bundle`.

If you mutate this after calling `read` at least once, you must call `unload` to reset the bundle.

### `parsers: string[]`

The array of parsers that you passed to `cush.bundle`.

If you mutate this after calling `read` at least once, you must call `unload` to reset the bundle.

### `project: Project`

The project that owns this bundle.

### `valid: boolean`

Equals `false` if a new build is required on the next read.

### `state: Object`

The bundle state that is reset at the start of every build.

Its `elapsed` property is the time elapsed before the last (successful) build finished.

Its `missing` property is an array of unresolved dependencies, where each value is an array like `[parent: Asset, dependency: {ref, start, end}]`

This object can be used by plugins to keep state that should be released when a new build starts.

### `time: number`

The timestamp of when the last (successful) build started.

### Methods

[Config methods](./config.md#config-methods) and [hook methods](#./hooks.md) are available.

These methods are also available:

### `relative(path: string): string`

Strip `this.root.path` from the start of the given `path`.

### `resolve(name: string): string`

Join the given `name` with `this.root.path` and resolve any `..` parts.

### `async read(): string`

Get the generated bundle.

If `this.valid` is true, the cached result is returned.

### `async use(plugins: string|Function|Object|Array): void`

Load the given plugins. These plugins are *not* added to `this.plugins`.

Only callable within a plugin or your `cush.config.js` module.

[Learn more](./plugins.md) about plugin values.

### `worker(arg: string|Function): void`

Extend the worker farm with a plugin.

If you pass a function, it should be declared where it's passed in. Otherwise, it won't be as easily debuggable. The function won't have access to anything outside it.

[Learn more](./workers.md) about workers.

### `getSourceMapURL(arg: string|SourceMap): string`

Generates a `sourceMappingURL=` comment.

Pass a string to use as the relative file path to the source map. The `.map` extension is added to the end for you.

Pass a `SourceMap` object (or any object with a `toUrl` method) to generate an inline source map (encoded in base64).

### `unload(): void`

Reset the bundle to be as if you just constructed it.

All assets, packages, and plugins will be reloaded on the next `read` call.

### `destroy(): void`

Destroy the bundle when it isn't needed anymore.

Once this is called, you'll need to use `cush.bundle` if you need the same bundle in the future.

You *must* call this to properly clean up the worker farm and stop any file watchers.

&nbsp;

## `Package` class

```js
require('cush/lib/Bundle').Package
```

Package objects are *not* shared between bundles.

Symlinks in `node_modules` are supported. These packages are considered locally developed, and are thus watched for changes.

### Properties

### `path: string`

The absolute path to the package directory.

### `data: Object`

The parsed contents of the `package.json` module.

Watched packages have this property kept updated.

### `main: ?Asset`

The main module of this package.

Equals `null` until used by an asset in the bundle.

### `assets: Object`

The asset map where keys are filenames relative to `this.path` and values are `Asset` objects, strings, or `true`.

A `true` value means the asset isn't being used by the bundle yet.

A string value means the asset is a symlink to another asset within the same package. Symlinks that lead outside the package are *not* supported (yet?).

Paths to nested packages (eg: `node_modules/foo`) won't exist until they are used by an asset in the bundle.

### `users: Set`

Packages that require one or more of our assets.

### `owner: ?Package`

The package containing us.

### `bundle: Bundle`

The bundle using us.

### `worker: ChildProcess`

The worker process dedicated to this package.

### `crawled: boolean`

Equals `true` if this package has been crawled, which means the `assets` object contains all existing files that are owned by this package.

### `watcher: ?Readable`

The event stream for file changes in this package. [Learn more](https://github.com/aleclarson/wch#wchstreamdir-string-query-object-readable)

### `skip: string[]`

An array of globs that will be ignored while crawling and watching this package. The glob syntax is described [here](https://github.com/aleclarson/recrawl#pattern-syntax).

Globs ignored by default are found [here.](../src/utils/ignored.coffee)

### Methods

### `relative(path: string): string`

Strip `this.path` from the start of the given `path`.

### `resolve(name: string): string`

Join the given `name` with `this.path` and resolve any `..` parts.

### `crawl(): this`

Populate the `assets` object of this package.

Uses [recrawl](https://github.com/aleclarson/recrawl) under the hood. Symlinks are only followed one level deep.

### `search(name: string, target: string, exts: string[]): ?Asset`

Try loading an `Asset` that matches the given arguments. The asset may have been loaded before.

Assets with the given `target` in their filename are preferred over those without.

When `name` has no *known* extension, the package looks for several variations in the following order:
- look for `name` as-is
- look for `name` with every implicit extension
- look for `name` as a directory by appending `/index`

Known extensions are defined by calling `Bundle#merge('known exts', [])`. Likewise, implicit extensions are defined by calling `Bundle#merge('exts', [])`. Bundle formats and plugins often set implicit extensions for you.

Some extensions are known by default, as defined in [this package.](https://github.com/cushJS/known-exts)

### `require(name: string): ?Package`

Try loading a `Package` that exists in the `node_modules` directory of this package. The package may have been loaded before.

If we are the first user of the returned package, we are set as its `owner`. That means if we are ever unloaded, this package will also be unloaded.

The given `name` must exist in the "dependencies" field of our `package.json` module. Otherwise, `null` is always returned.

If the dependency's expected location is empty, we ask our parent package to look for it. This will continue up the ancestor chain until the bundle root is checked or the package is found.

&nbsp;

## `Asset` class

```js
require('cush/lib/Bundle').Asset
```

### Properties

### `id: number`

An integer unique to the bundle.

### `name: string`

The file path relative to `this.owner.path`.

### `owner: Package`

The package containing us.

### `content: string`

The content after being transformed by plugins.

If no plugins were used, this is the original content and `map` will be null.

### `deps: ?Object[]`

The parsed dependencies, in order of appearance.

Equals `null` if the asset has no dependencies.

The objects are shaped like `{ref, start, end, asset}`.

The `asset` property is where the resolved asset is cached.

### `map: ?Object`

The source map.

### `time: number`

When this asset was last updated.

Set this to `Date.now()` to invalidate dependencies that resolved to this asset.

### Methods

### `path(): string`

The absolute path.
