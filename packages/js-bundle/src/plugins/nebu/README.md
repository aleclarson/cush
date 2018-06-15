# cush-plugin-nebu

The preferred alternative to [Babel][1] for plugins that transform Javascript.

### [Learn more][2]

[1]: https://github.com/babel/babel
[2]: https://github.com/aleclarson/nebu

## Configuration

Each package can have its own `nebu.config.js` module that customizes its plugins and other options.

The `"nebu"` hook provides access to the state of each module after its plugins are used.
