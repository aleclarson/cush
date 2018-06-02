
## Bundle formats

`cush` comes with JavaScript and CSS bundle formats baked in.

Bundle formats can have these properties:

- `type: ?string` format identifier assigned to every bundle
- `exts: ?string[]` file extensions for implicit resolution
- `match: ?function` detect if a bundle should use this format
- `plugins: ?function[]`
- `mixin: ?object` values assigned to every bundle

The `match` property takes precedence over `exts`. If `match` is undefined, then
`exts` is used to match a bundle by its entry file's extension.

Each function in the `plugins` array is called with a new `Plugin` object as its
context and a `Bundle` object as its only argument.

In the `mixin` object, any property names that begin with an underscore are
made non-enumerable when assigned.

### Customization

Add your own bundle format:
```js
cush.formats.push(require('xxx-bundle'));
```

Add a plugin to an existing bundle format:
```js
let form = cush.formats.find(form => form.type == 'js');
form.plugins.push(require('cush-xxx'));
```

When adding a format or plugin, any bundles that existed beforehand are not
affected. If that behavior is undesired, you'll need to destroy the bundle and
remake it.
