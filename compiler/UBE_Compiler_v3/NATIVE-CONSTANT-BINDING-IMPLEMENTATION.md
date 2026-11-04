# Anonymous native constant contributions

This implements the remaining anonymous read-only contribution mapping required
by the existing relocation/instruction correspondence work. It applies to a
nonempty, fully initialized, resident read-only object section with no relocations,
code, zero-fill, link-info/remove or COMDAT attributes. Object alignment must be
explicit (COFF alignment code 1 through 14). Its primary section symbol is STATIC,
type zero, value zero, with one auxiliary record and an exact section-name match.
The auxiliary length must equal the section length, relocation/line counts must
be zero, section number must be zero or this section, and selection/reserved bytes
must be zero. The non-COMDAT checksum is read but has no semantic constraint.
These fields follow the [PE/COFF section-definition format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#auxiliary-format-5-section-definitions).

TryBindNativeConstantContribution receives that raw symbol index, the immutable
object inventory/snapshot/layout and the immutable image snapshot/layout. The
caller retains every owner and its prepared-layout association. It examines every
aligned candidate within initialized resident read-only image sections. A match
must include the complete object section, excluding PE file-alignment padding.
It fails for no match or more than one match, including overlapping matches.
After selecting a unique match, it rejects overlap with another section's logical
virtual range or initialized file range. Names, instruction operands and fixup
values do not supply the candidate address.

The atomic result is a NativeRetainedDefinition with Present=1 and complete equal
object/image byte spans. Its object symbol index is the input primary symbol;
the anonymous image range has SymbolIndex=-1. Its image section offset, RVA and
absolute address are checked before publication. This establishes one constant
contribution by complete immutable content and unique placement. The build owner
must bind each distinct input contribution once and preserve those associations;
cross-object contribution overlap/alias policy remains a required integration
check. This operation never silently accepts arbitrary, relocated, mutable,
discardable or COMDAT sections as constants.

The compiler owns section eligibility, alignment, auxiliary-record meaning,
unique-contribution selection and mapping policy. Scalar decoding reuses UBECore's
qualified little-endian reader through the shared NativeInspection budget. No
generic collection or separate search subsystem is introduced. Comparisons use
chunks of at most eight bytes and stop at the first mismatch at each candidate.
For section length L and C examined candidates, payload comparison reads at most
2*C*L bytes in 2*C*ceil(L/8) events. Section/name/auxiliary checks add their actual
bounded reads. A successful call makes two image-section walks; a second match
can reject earlier. Work is bounded by the existing shared byte/event caps, which
admit before every read. No numeric cap or declaration/body/argument bound changes.

All workspace is scalar: no allocation, retained ownership or payload copy.
The operation is reentrant, preserves Err and immutable inputs, and publishes
only after all checks succeed. Missing/ambiguous/unsupported or malformed candidate
data uses 1506; invalid owner state uses 1509; budget exhaustion uses 1502/resource 7;
cancellation uses 1507. Every failure preserves the previous result.

Qualification requires independently placed synthetic contributions (unaligned
file offsets, address alignment, short/final chunks, overlapping duplicates,
wrong permissions, padding-only matches and mapped aliases), auxiliary/owner
failures, exact/one-below budgets, all cancellation admissions, allocation
independence and root refusal. The eight retained O0 support objects and their
two section relocations each must compare against an independent full-byte
occurrence oracle, with corrupted, duplicate and missing/permission controls.

Relocation arithmetic, full instruction equality, cross-object aliases, pointer
cells, import/TLS semantics and stack/debug/publication acceptance remain required.
An anonymous constant match does not prove those properties or whole-program
retention. Named relocation resolution retains its separate supported boundary.

The common TryValidateNativeContributionIsolation consumer now performs the
final image overlap check, including the image symbol/string table as well as
other sections. It adds one zero-byte admission and retains scalar workspace
and the same atomic publication. NATIVE-BINDING-IMPLEMENTATION.md defines it.

Constant and code content comparisons also share TryCompareNativeByteSpan,
whose admission, equality-result and failure contract is recorded in
NATIVE-OBJECT-IMPLEMENTATION.md. Chunk sizes and byte/event bounds are unchanged.
