# UBE IDE application design

**Status:** Steps 1 through 3 verified foundations

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

## Step 2 native shell

The shell keeps state and policy in UBE and reaches native windows through the
narrow boundary documented in `PLATFORM.md`:

```text
UBE application
  -> locale, commands, validated layout, atomic persistence
  -> versioned bounded shell configuration/result
  -> Win32 adapter: HWNDs, messages, monitors, DPI and accessibility
```

The temporary process transport exists because Compiler v3 RP8
does not lower arbitrary foreign imports and callbacks. It is not an
alternative application architecture: the adapter cannot own documents, undo,
settings, compiler state, or user-work safety decisions.

Step 2 uses standard Unicode Win32 windows and EDIT controls with neutral
system presentation. Project Explorer and Properties begin on the right,
Output begins at the bottom, and each placeholder can be hidden, reopened,
floated, moved by the operating system, docked again, or restored through
Reset Layout. Final colors, type, metrics, and icons remain intentionally
undecided.

## Step 3 real-document slice

One real UBE source file now opens through the UBE document model and appears
in an editable standard Win32 EDIT control. The native view atomically
checkpoints edits and returns a bounded versioned session record; it does not
decide whether project source may be overwritten. UBE validates document
identity and base version, retains undo history across view detach/recreation,
detects external changes, writes recovery first, and uses RP8's durable atomic
text publication for an accepted save. Save, Discard, Cancel, clean close,
stale results, malformed results, host failure, and every save boundary are
ordinary controlled outcomes.
