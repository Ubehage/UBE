# UBE 1.0 foreign-library ABI contract

**Status:** normative UBE 1.0 contract for Compiler v3

`Public Export` produces a target-specific shared-library symbol plus
versioned machine-readable ABI metadata and generated C-compatible declarations.
Foreign callers never depend on UBE compiler-internal layout or garbage-
collector addresses.

## Call shape and status

Every generated entry point returns a fixed ABI status code. A UBE Function's
logical result is written through a validated out parameter only on success.
Subs use the same status return without a result slot. No UBE `Err`, exception,
or unwinding state crosses the foreign boundary.

Status zero means success. Nonzero statuses identify invalid arguments,
conversion failure, unloaded/stale handles, cancellation, out-of-memory, and
controlled internal failure. The generated metadata defines the stable numeric
codes and the function that copies bounded diagnostic text for the calling
thread.

## Scalars and text

ABI declarations use exact-width integer and IEEE types, never host C `long`:
`Byte` is `uint8`, `Integer` is `int16`, `Long` is `int32`, `LongLong` is
`int64`, pointer-sized integers use target `intptr/uintptr`, `Single` is binary32,
`Double` is binary64, and `Currency` is signed `int64` scaled by 10,000.
Boolean crosses as signed `int32` with only 0 and -1 emitted.

Strings cross as explicit UTF-8 pointer-plus-`uint64`-length views for input.
Returned/output strings use caller-provided buffers with a size-query operation
or an opaque owned value handle. They are never NUL-termination dependent and
foreign code never frees UBE storage directly. Decimal and Date use versioned
generated records rather than a host compiler's incidental struct layout.

## Custom values

A custom datatype returned or passed across the ABI is represented by an opaque
owned value handle plus generated typed field copy/access operations. This
supports recursive and managed fields without exposing moving addresses or
platform padding. Acquiring/copying a value handle creates an independent
semantic value copy; releasing it is idempotent. ABI metadata contains the
source type identity and schema hash so incompatible clients fail safely.

An optional direct C record may be generated only for a type explicitly proven
ABI-safe: nonrecursive, fixed-size, containing solely fixed-width ABI scalars,
with versioned offsets/alignment recorded. It does not replace the opaque form.

## Objects and modules

Objects/classes/forms/controls and exported module identities use opaque
generation-checked handles. Each acquisition creates the approved independent
external lease. Releasing one lease preserves all others. Identity-wide
self-unload invalidates every handle; release of an invalidated handle remains
harmless, while other calls return unloaded/stale status.

The library owns handle tables, managed roots, and internal resources. An
orderly generated library-shutdown operation rejects new calls, drains active
calls, performs module/object cleanup, invalidates handles, and releases linked
support. Host-forced unload without that operation cannot promise arbitrary
user cleanup, but must never leave a subsequent valid entry point into removed
code.

## Threads and callbacks

Each foreign entry establishes an UBE thread transition and independent `Err`
state if the calling native thread is not already registered. Foreign callbacks
are represented by explicit function pointer plus context records whose calling
convention, lifetime, and thread rules are in metadata. Callback records must
be released before their foreign code is unloaded.

Those generated callback records are distinct from the classic `AddressOf`
bridge used when UBE calls a metadata-free native API. `AddressOf` supplies a
compiler-generated entry thunk only as a foreign-call argument and carries no
context record or automatic unregistration. User code owns that native
registration and must remove it before program/library shutdown or before the
foreign recipient unloads. Managed values may cross only when versioned binding
metadata defines their representation; a raw callback signature is otherwise
limited to ABI-safe fields.

## Versioning and validation

Metadata records ABI major/minor version, target triple, endianness, pointer
width, calling convention, exported signature hashes, type schema hashes, and
ownership operations. Major mismatch, wrong target, malformed metadata,
unknown handle generation, null required pointer, excessive length, or buffer
overlap is a controlled status result and never an unchecked access.
