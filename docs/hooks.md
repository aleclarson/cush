# Hooks

"Hooks" are functions that listen to a `BundleEvent` object.

- [**Hooks not available to workers**](./fs.md#hooks)
- [**Hooks only available to workers**](./workers.md#hooks)

The following methods are always available on bundles (even in workers).

#### `hook(id: string, fn: Function): this`

Hook into an event.

Your function is called after all existing hooks, unless they were added with `hookRight`.

#### `hookLeft(id: string, fn: Function): this`

Hook into an event.

Your function is called before all existing hooks.

#### `hookRight(id: string, fn: Function): this`

Hook into an event.

Your function is called after all existing hooks.
