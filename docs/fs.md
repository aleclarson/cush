# Virtual filesystem

The `cush.packages` property maps a package name to its version table, which
maps a package version to its `Package` object.

```js
const pack = cush.packages[name][version]
```

`Package` objects have these properties:
- `root: string`
- `data: object` the parsed value of `package.json`
- `deps: object`
- `clock: ?string` time of last file change
- `files: ?object`
- `bundles: Set` bundles that use this package
- `exclude: string[]` file globs to ignore

The `deps` object maps a package name to its package object. Only packages that
exist in `data.dependencies` are stored here. The `deps` object is only filled
when you call the `require` method.

The `files` object maps a filename (relative to `root`) to its file object. Only
files within `root` are stored here. The `files` property equals null until you
call the `crawl` method.

File objects with these properties:
- `id: number`
- `name: string` relative to package root
- `ext: string` file extension (may change from plugins)
- `content: ?string`
- `map: ?object` source map (v3)
- `ast: ?object` abstract syntax tree
- `imports: ?object[]` external file references

The `imports` array holds objects with these properties:
- `ref: string`
- `start: number` character index within the file

The `cush.crawl` method returns a promise that is resolved once a package has
been crawled.

### Packages

When a bundle is created, the package of its main module is found. This package
has its `package.json` read and its `node_modules` is checked for missing
dependencies. Any package found in `node_modules` that also exists in the
`dependencies` field of its parent's `package.json` goes through the same
process. This happens until all packages have been registered.

Packages don't have their `files` property set until their module dependencies
need to be resolved.

Symlinks in `node_modules` are supported. When 2+ symlinks point to the same
version of a package, they must also point to the same directory.

### Module resolution

For non-relative references (eg: `lodash`), the package is resolved by looking
in `node_modules` for a match. Recursive lookup is *never* performed. Global
package directories (eg: `$NODE_PATH`) are *never* checked.

For relative references, it's assumed the module is in the same package.

When a reference points to a directory, it's assumed the module wants to import
`/index` and the dependency can have any extension. When multiple `/index` files
exist, a warning is given. When a file exists with the same name as a directory,
the file takes precedence.

Implicit extensions are defined by the bundle format's `exts` property.
All other extensions must be used explicitly.

Absolute paths are *not* supported.

### Bundles

Bundle objects have these properties:
- `modules: Module[]` modules used by the bundle
- `packages: object[]` package objects used by the bundle

Because package objects are shared between bundles, any plugins should use a
`WeakMap` to keep package-specific data isolated from other bundles.

The `modules` property maps a `cush.packages` object to its module map, which
maps a file object to its `Module` object.

When a module map is empty, its associated package is no longer used by the
bundle.

The `Module` objects are unique to each `Bundle` object. This lets plugins
modify them in isolation from other bundles.

`Module` objects have these properties:
- `file: object`
- `pack: object`
- `content: ?string`
- `map: ?object` source map (v3)
- `ext: string` file extension (may be changed by plugins)

### Bundling

Bundling may be cancelled at any time with the `bundle.cancel` method.

We always start with the bundle's main module.

When a dependency resolves into a new `Module` object, it must be processed
before more dependencies are resolved. First, modules are read into memory if
necessary. Then, they are processed by any applicable plugins. Afterwards, we
pass the module to the `bundle._wrapModule` method. Unchanged modules are
preserved between rebuilds.

After all dependencies are resolved, the `bundle._finalize` method is called,
which merges every module into one string (known as the bundle string).

Unless this is the first bundle, there's a little more work left. We need to
compare the `modules` arrays from both results, which helps us determine if a
package object is no longer used by the bundle. Then, we need to emit the
`package:drop` event for each unused package object.

### File changes

- Map/parse file (if loaded)
- Find bundles that use the file's package
- Call `bundle._onChange` with the file event
- For bundles that use the file, trigger a rebundle
- For bundles with missing deps, trigger a rebundle

### Utility functions

- `readFile(file)`
  - return `content` if not null
  - read from native filesystem
  - transform to parseable format if necessary
  - parse AST and imports if possible
