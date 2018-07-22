# cush/utils

This document describes utility functions provided by `cush/utils`.

🚧 *Under construction*

### ErrorTracer

The `ErrorTracer` function takes two arguments:
- `sources: Source|Array<Source>` where `Source = {content: string, map: Object}`
- `options: Object` with [these properties](https://github.com/aleclarson/sorcery#options)

It returns a `trace` function that takes two arguments:
- `error: Error` the syntax error that needs tracing
- `filename: ?string` the fallback filename if tracing fails

The `trace` function mutates the properties of the given error,
which must have `line` and `col|column` properties to be traced.

The `line` and `col|column` properties must be one-based.

The error has its `line`, `col|column`, and `file|filename` properties updated
when the generated location can be traced to an original source.
