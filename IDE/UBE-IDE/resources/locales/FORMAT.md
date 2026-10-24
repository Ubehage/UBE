# UBE IDE locale format

`UBE-Locale 1` is the dependency-free localization format used by the IDE.
Files are UTF-8 text and begin with this exact header:

```text
UBE-Locale 1
Locale = "en"
Fallback = "en"
Command.File.Save = "Save"
```

`Locale` is required. `Fallback` is optional for the canonical English catalog
and required when a translation intentionally relies on another catalog.
Keys are case-insensitively unique. Empty lines and lines whose first
non-whitespace character is `'` are ignored. Values are quoted; a literal quote
is written twice.

Keys describe semantic purpose rather than location or current English wording.
Normal UI source code contains keys, not display text. Diagnostic code
`IDE1001`, for example, resolves through `Diagnostic.IDE1001`.

Message placeholders are named and typed:

```text
Build.Summary = "Built {project:text} with {errors:long} errors"
```

The initial supported types are `text` and `long`. `{{` and `}}` emit literal
braces. Missing arguments, mismatched types, malformed braces, unknown types,
duplicate keys, invalid UTF-8, unsupported headers, fallback cycles, and
configured-limit violations are controlled errors. Program values are inserted
as data and are never reinterpreted as placeholder syntax.

Locale files are repository-owned and packaged for offline use. Missing entries
fall back deterministically. A translator coverage check must report missing,
unused, duplicate, and placeholder-incompatible entries before release.

