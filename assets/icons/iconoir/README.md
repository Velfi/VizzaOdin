# Iconoir Controller Icons

These SVGs are a small vendored subset of `iconoir@7.11.1` from npm.

The original SVGs are kept in `regular/`. Rasterized white-on-transparent PNGs
are generated in:

- `png/48/`: 2x Retina output from the 24px Iconoir source.
- `png/96/`: 4x output for larger 4K-targeted controller UI scaling.

Prefer the 96px assets when the icon may be scaled up in a 4K viewport. Use the
48px assets for fixed-size controls near the original Iconoir 24px design size.

## Controller mapping

- Play: `play`
- Look: `color-wheel`
- Brush: `design-pencil`
- Motion: `transition-right`
- Awareness: `compass`
- Field: `droplet`
- World: `planet`
- Birth: `sparks`
- Capture: `video-camera`
- Presets: `database-script`

## License

Iconoir is MIT licensed. The package license is included at `LICENSE`.
