# Bundling

This document describes the order in which the bundle is generated.

## First build

### 1. Configure the bundle

The bundle is configured in the following order:
- ask the bundle format for a fresh config object
- call the `init` function passed to `cush.bundle`
- call plugins in the order they were defined
- call the format-specific function defined in `cush.config.js`
- run hooks for the `config` event
- tell the bundle format that the config is ready
- load the bundle on every worker process

### 2. Resolve and load assets

Resolving assets is described in the ["Asset resolution"](#asset-resolution) section at the bottom of this document. This phase occurs while assets are being loaded. Even though assets are loaded in parallel, the bundler tries to keep assets in logical order by batching assets based on when they are imported. Once every asset in a batch is loaded, its dependencies are resolved and pushed into the next batch. The next batch won't be loaded until all dependencies in the previous batch are resolved.

Asset loading occurs entirely in worker processes. The content of each asset is read by a worker that passes a temporary asset into a plugin pipeline that can transform the asset and then parse its dependencies. The dependencies are never resolved by workers. Assets are never cached by workers.

### 3. Concatenate the assets

Once all assets in the bundle are loaded, the bundle format gets to decide how the generated bundle should be created. This involves ordering and concatenating the assets into a single string. A source map will be created that allows the developer to trace errors back to the original source code.

&nbsp;

## Rebuilds

File changes trigger automatic rebuilds of affected bundles.

### 1. Update the asset tree

The entire asset tree is traversed to look for changed assets that need reloading, new assets that need loading, and unresolved dependencies that need resolving. At the end, any packages that were used in the last build, but not this build, are unloaded to save memory.

### 2. Concatenate the assets

*Nothing different from the first build.*

&nbsp;

## Asset resolution

For non-relative references (eg: `lodash`), the package is resolved by checking the "dependencies" object in `package.json` where to look. The default location is in `node_modules`. If the package cannot be found, the ancestor chain is traversed until the package is found or the bundle root is reached. Global package directories (eg: `$NODE_PATH`) are *not* supported.

For relative references, the asset must be in the same package.

When a reference points to a directory, the `/index` asset is imported. When a file exists with the same name as a directory, the file takes precedence.

Absolute paths are *not* supported.
