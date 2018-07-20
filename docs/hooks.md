# Hooks

"Hooks" are functions that listen to a `BundleEvent` object.

The following methods are always available on bundles (even in workers).

[Learn](./fs.md#hooks) about hooks available in main process only.

[Learn](./workers.md#hooks) about hooks available in workers only.

### `hook(id: string, fn: Function): this`

Hook into an event.

Your function is called after all existing hooks, unless they were added with `hookRight`.

### `hookLeft(id: string, fn: Function): this`

Hook into an event.

Your function is called before all existing hooks.

### `hookRight(id: string, fn: Function): this`

Hook into an event.

Your function is called after all existing hooks.
