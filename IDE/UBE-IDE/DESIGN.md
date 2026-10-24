# UBE IDE application design

**Status:** Step 1 headless foundation

The application core is divided into deterministic UBE modules. It owns state
and policy but reaches files, processes, compiler services, debugger services,
and native windows only through narrow adapters.

The Step 1 dependency direction is:

```text
headless verification
  -> workspace, documents, undo, commands, settings, localization, protocols
  -> diagnostics, text helpers, limits
  -> bootstrap host intrinsics and narrow file-commit helper
```

Documents own text, saved state, version, dirty state, and recovery identity.
Views never own document contents or undo history. Step 1 undo records complete
buffer replacements; later editor structures may optimize storage without
changing the transaction contract.

Atomic publication is reached through a narrow storage adapter. The current
bootstrap `WriteAllText` intrinsic writes a sibling temporary file, flushes it,
and atomically replaces or creates the destination. A failed publication
preserves the previous destination and removes the abandoned temporary file
when possible. Recovery publication uses the same adapter.

Settings and locale catalogs use bounded, versioned UTF-8 line formats.
Unknown settings are preserved by the parsed key/value model. Locale values
are addressed by semantic keys and deterministic fallback is performed by the
caller; malformed catalogs never replace the last valid catalog.

Service envelopes are bounded data records with protocol version, request ID,
document version, method, status, and payload. Step 1 verifies framing and
stale-result detection with synthetic messages; no compiler internal record is
part of the contract.
