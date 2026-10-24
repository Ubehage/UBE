# UBE IDE icon source

The core icon family is original UBE project artwork authored for Step 7 in
2026 with AI assistance. It is distributed under the repository's MIT
license. `icon-source.json` is the canonical source: a 24-unit, pixel-aligned,
outline family with a 1.75-unit stroke, square joins, rounded caps only where
they aid recognition, and two units of optical padding.

Icons use `currentColor`, so normal, hover, pressed, disabled, selected, dark,
and high-contrast states come from semantic theme roles. Shape and accessible
text carry meaning; color is never the only cue. Ambiguous docking icons are
always paired with accessible command names and are text-labelled in menus.

`generate-visual-assets.ps1` deterministically exports 16, 20, 24, and 32 px
SVGs. The generated files belong under `out/visual/`; packaged raster/ICO
conversion can be added when the native packaging toolchain is frozen without
changing the canonical geometry.
