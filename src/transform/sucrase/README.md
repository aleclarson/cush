# cush-sucrase

This transformer handles [Flow][1], [TypeScript][2], [JSX][3], and ES modules.

Learn more [here][0].

[0]: https://github.com/alangpierce/sucrase
[1]: https://github.com/facebook/flow
[2]: https://github.com/Microsoft/TypeScript
[3]: https://reactjs.org/docs/jsx-in-depth.html

### Flow

Flow types are stripped from modules whose packages' `devDependencies` contain [flow-bin](https://www.npmjs.com/package/flow-bin).

### JSX

Modules that contain JSX must use the `.jsx` file extension.

### ES modules

`module.exports = exports.default;` is used when a module only has an `export default` statement. This eliminates the need for `require('es-module').default`.
