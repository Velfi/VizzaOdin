# Third-Party Dependencies

## tomlc17

`tomlc17` is downloaded from <https://github.com/cktan/tomlc17> by `make deps`
and is intentionally ignored by Git.

It is used behind VizzaOdin's `settings` facade for TOML-compatible app
settings and simulation presets. Simulation code must not call the C API
directly.

Build it with:

```sh
make deps
```
