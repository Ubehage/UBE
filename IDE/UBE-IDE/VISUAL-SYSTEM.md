# UBE IDE initial visual system

**Status:** frozen initial system for Step 7

The visual personality is **modern-classic**: the directness, density, and
stable spatial memory of classic native development tools, refined with calm
spacing, strong focus treatment, and restrained contemporary geometry. It is
purposefully not a browser-dashboard aesthetic and does not imitate another
IDE.

Semantic colors, syntax colors, typography, and metrics live in the three
versioned resources under `resources/themes/`. Light uses a warm neutral
canvas with a paper-like editor; dark uses neutral charcoal rather than blue-
black; high contrast is black/white with cyan selection and yellow focus.
Controls request roles from `IdeVisualSystem`; literal colors do not belong in
individual controls. Operating-system high-contrast choices may override the
provided palette.

Normal and muted text, selection text, focus, diagnostic states, debugger
states, and every syntax category are contrast-tested against their actual
background. Selection, focus, error, warning, changed registers, and current
execution state all have a shape, label, border, or glyph in addition to
color. Animation is short and nonessential in light/dark and disabled in high
contrast.

Metrics use a four-pixel spacing unit at 96 DPI, one-pixel borders, two-pixel
focus rings, 30-pixel toolbars, 22-pixel tree rows and status bars, and
28-pixel tabs. The platform rounds once from logical pixels at 100%, 125%,
150%, 175%, and 200%. Text determines control width; English captions are not
used as fixed-size templates. The reference screens include long, right-to-
left, and fallback-font samples.

Syntax roles map to compiler concepts rather than lexer guesses: keyword,
declared type, string literal, numeric literal, comment, resolved procedure,
resolved constant, operator, and ordinary identifier. Diagnostics and debug
overlays remain separate roles so semantic color never changes token identity.

The Code, Design, and Debug SVGs under `resources/visual/` are the reference
screens. They demonstrate the accepted right-side Project Explorer, compact
native density, dark designer, and non-color high-contrast debug cues. The
original icon source, authorship, license, geometry, states, sizes, and
deterministic export procedure are documented under `resources/icons/`.
