# Retained code contribution comparison

TryValidateNativeCodeContribution consumes a present one-byte function anchor
from TryBindNativeDefinition, the same immutable object/image owners and ready
inventories, and the shared inspection/cancellation ledger. The build owner must
select anchors from frozen expected rows belonging to that output unit. Arbitrary
candidate names do not establish expected ownership. No new build phase or
public intermediate representation is introduced.

The anchor's object offset and image offset establish the placement of its
complete ordinary COFF code section. The section must be nonempty, entirely
initialized, resident readable executable code without write, COMDAT, link-info,
remove, discardable, data or uninitialized-data flags. Its explicit COFF
alignment must be respected by the image contribution base. The image extent
must fit initialized logical section bytes, the image RVA domain and signed
address domain. Anchor fields must agree with the decoded sections. Other image
sections must not overlap the contribution virtually or through initialized file
bytes; other object initialized sections, relocation tables and either owner's
symbol/string table must not alias the compared code bytes.

The qualified pinned tool's non-ABSOLUTE code relocation fields are in increasing
nonoverlapping order. The consumer checks that condition and reads each record
once. ABSOLUTE records occupy no field. Named targets use the existing resolver;
anonymous section targets use the existing complete constant binder. Each field
uses TryValidateNativeRelocationValue. Every intervening and trailing byte is
compared through the shared TryCompareNativeByteSpan inspection helper in
chunks of at most eight bytes. A successful comparison therefore
covers all original section bytes exactly once as code content, including code
alignment bytes. Target resolution, section headers and relocation records add
their separately admitted reads. No linked byte or relocation operand is used
to infer placement.

The result is a NativeRetainedDefinition with Present=1 and whole contribution
ranges. Both SymbolIndex fields are -1 because these describe sections, not a
single function. The object section offset/RVA/address are zero; both TypeCode
fields are 32. The image range retains its section offset, file offset, RVA and
VA. Result publication is atomic. An absent optional definition is handled by
the caller and does not enter this consumer.

All owners are borrowed and immutable. Workspace is scalar; there is no payload
allocation, payload copying, retained ownership or mutable shared state. Each
target resolution is charged when performed, including repeated targets; no
unmeasured cache is assumed. Successful code-content reads are exactly twice the
section length. Other cost is the bounded section walk, one relocation-record
walk and the existing target-resolver costs. All use the same byte/event caps
and cancellation admissions. No numeric or declaration/body/argument bound
changes. Invalid caller state uses 1509; unsupported/mismatched candidate data
uses 1506; budgets use 1502/resource 7 and cancellation 1507. Existing root-refusal
behavior must retain the old result.

A diagnostic over the retained 144 object/image pairs found 112 nonempty code
sections (146,088 bytes, 5,712 relocations), each with a frozen expected function
anchor and one consistent placement. All fields were ordered and nonoverlapping.
bootstrap/out/native-code-placement-diagnostic.json records the observations;
this is implementation guidance, not production acceptance.

Qualification requires synthetic unchanged bytes, mixed relocation fields,
ABSOLUTE records, alignment and anchor boundaries; byte/field/target mutations,
overlap/order/section-alias refusals; exact budgets, every cancellation admission,
no allocation/copy, immutable owners and atomic old-result retention. Retained
artifact tests must start from frozen expected rows and compare complete output
ranges against an independent oracle, with changed linked bytes, addends,
symbols, section extents and overlapping fields rejected.

Complete-build ownership still must ensure that every required code contribution
is covered once, every retained anchor agrees with its unit's placement and
distinct object contributions do not improperly alias in the image. This byte
consumer does not infer function extents or prove instruction boundaries,
effective target safety, pointer-cell/import/TLS meaning, unwind/stack/debug
semantics, tool/build ownership or publication safety. Those remain required.
