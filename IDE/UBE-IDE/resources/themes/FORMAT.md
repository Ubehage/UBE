# UBE IDE theme resource format

`UBE-IDE-Theme 1` files are bounded UTF-8 resources owned by the IDE. Every
theme contains the same semantic color, syntax, typography, and metric keys.
Controls consume named values through the visual-system service; they do not
embed palette literals.

Colors use opaque `#RRGGBB`. Metrics are device-independent pixels at 96 DPI
and scale through the platform adapter at 100%, 125%, 150%, 175%, and 200%.
Missing, duplicate, malformed, oversized, or unknown fields reject the
candidate resource while the last valid theme remains active. High-contrast
mode disables decorative animation and permits the operating system to
override colors.

The UI stack is `Segoe UI`, `Tahoma`, then the native default UI font. The
editor stack is `Cascadia Mono`, `Consolas`, then `Courier New`/the native
fixed-pitch font. These are referenced system fonts and are not redistributed
or downloaded by UBE. The application remains usable when only the native
fallback exists.
