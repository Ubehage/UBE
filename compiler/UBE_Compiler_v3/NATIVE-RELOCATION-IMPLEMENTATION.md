# Native relocation target association

This is a prerequisite of the existing instruction/fixup correspondence obligation
under First checked native executable. It does not replace that obligation.

TryResolveNativeNamedRelocation consumes a non-ABSOLUTE relocation description
from the qualified object reader, the object's immutable prepared symbol inventory,
and the linked image's immutable snapshot, layout and prepared inventory. The
caller preserves each inventory/snapshot association. The target must be a primary
EXTERNAL or STATIC symbol with a nonempty name, type zero or function type 32,
and no auxiliary records. Undefined targets must be ordinary EXTERNAL declarations
with value zero. COMMON, weak, absolute, debug and section-definition targets are
rejected. These restrictions are explicit supported-input boundaries, not grounds
for silently ignoring a required relocation.

A defined object target must resolve uniquely by its name back to the exact raw
symbol index named by the relocation, with one byte of logical section storage.
The image must contain exactly one positive-section definition of the same name
with one byte of logical storage. Defined object types and explicit undefined
function types must match the image type. Undefined type zero permits either
data or function resolution. Functions must be initialized readable executable
nonwritable code on both applicable sides. Data may use zero-filled storage.
The atomic result is the image NativeDefinitionRange; it is an anchor, not the
target's complete extent. Existing range resolution checks RVA/address arithmetic.

The operation borrows all owners, uses fixed scalar workspace, allocates and copies
no payload, and has no shared mutable state. Every indexed visit, name comparison
and section read uses the caller's shared inspection budget and cancellation token.
Work consists of one primary-target visit, one existing object lookup for defined
targets, and one existing image lookup, with their bounded section reads; there is
no section or symbol-table rescan outside those indexed lookup algorithms. Err,
input owners and old output are preserved on failure. Unsupported/missing/ambiguous
targets use 1506; bad owner association uses 1509; inspection exhaustion uses
1502/resource 7 and cancellation uses 1507. No resource caps or declaration/body/
argument work bounds change.

Qualification requires hand-specified defined/undefined/function/data/zero-fill
cases, ambiguous and unsupported targets, exact/one-below inspection limits,
every cancellation admission, allocation independence, root-pressure refusal,
atomic failures and independent SDK comparisons on retained generated objects.
Actual anonymous section references must be counted and explicitly rejected here.

The current generated code also contains anonymous read-only error-support string
references. Their contribution mapping remains required, as do relocation value
evaluation, overlap checks, full instruction-byte correspondence, pointer-cell
contents, import/TLS semantics, stack/debug analysis and publication integration.
A named anchor alone does not establish any of these properties.
