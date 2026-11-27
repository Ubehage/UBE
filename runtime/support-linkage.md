# Linking ordinary UBE managed support

Status: source-domain loading, role resolution and automatic installed-source
integration have passed their focused acceptance gates. String and Single/Double
qualification is recorded in compiler/Progress.md and compiler/FLOATING-POINT.md.
This document uses the existing
compiler target-support boundary as the integration point. It does not add a
source package, manifest key, language attribute, or implicit library reference.

The current installed closure contains 13 ordered source files and resolves
11 ordinary procedure roles, including floating text conversion and power.
`runtime/managed-support-sources.txt` is the file inventory; generated identities
and role checks qualify that exact closure. Numeric algorithms remain in UBE.

## Contract and current evidence

`lang-doc/managed-memory.md` requires the collector and target primitives to be
linked into programs needing managed memory. The collector algorithm remains
ordinary UBE. `compiler/TEXT-SUPPORT.md` requires validated support identities
for text operations and precise lifetime handling.

`lang-doc/project-files.md` separately requires explicit source references and
direct-reference-only public lookup. Therefore automatic managed support must
not inject its module names or Public procedures into a user's source namespace.
The user must be able to name a module `ManagedMemory`, `Text`, or `Utf8` without
changing compiler-selected operations or causing duplicate module diagnostics.

Currently `CompilerAssets` reads three fixed compiler-relative support assets;
`CompilationRequest` protects them against output replacement. `ProjectLoader`
loads the explicit source manifest into request-owned arenas. Declaration and
expression binding use one package name and one module namespace; merely
appending support sources would violate lookup isolation. `NativeLowering`
already prepares one complete symbol/layout/plan set before parallel emission.
That complete-plan boundary is retained.

## Source ownership and lookup

Install a fixed, reviewed closure of the existing ordinary UBE support sources
beside the compiler. Keep their authoritative production files in the standard
library; packaging copies them, rather than maintaining algorithm duplicates.
The closure's file order and required procedure signatures are compiler support
metadata. Loading never consults the current directory, environment, network,
or a user manifest's search paths. No source spelling grants support identity.

Retain trusted lookup-domain metadata with each parsed module. Explicit project
sources use the project domain; installed support uses the private support
domain. Source parsing cannot set this metadata. Both domains retain normal
module/procedure visibility within themselves. Support cannot resolve project
members, and project code cannot resolve support members, even through a
qualified name. Private members remain private to their module in either domain.
This is a compiler-owned target-support visibility distinction, not an
approximation of the unimplemented source-reference graph.

Use the same final source, token, node, symbol and layout arenas, with stable
combined IDs. Module lookup keys include the domain as well as the name;
cross-module unqualified searches stay in the caller's domain. Every qualified
lookup and type lookup follows the same rule. Do not rely on inaccessible-looking
names or on checking visibility only after choosing an ambiguous symbol.

After binding, resolve the required support roles from the installed closure's
module/procedure identities, validate exact parameter types, passing modes,
result type and body presence, then store bound symbol IDs in request-owned
planning facts. Compiler-generated calls use those IDs. They never search user
symbols by procedure spelling. Support roles are not new source Intrinsic
declarations: their bodies are lowered by the ordinary compiler. Native
primitive declarations within those bodies keep normal primitive-role checks.

Installed source bytes also match compiled reviewed identities before parsing.
`managed-source-identities.ps1` generates `ManagedSourceAssets.bas` from the same
fixed source ledger and the build verifies it. Canonical CRLF/LF length and two
order-sensitive Adler sums avoid checkout newline drift. This detects accidental
corruption, consistent with the native runtime asset checks; it does not
authenticate a hostile compiler installation. Checks consume the same owned
bytes that parsing uses, without reopening the file between validation and use.
NativeLowering also checks private source spans before granting emission roles
to caller-supplied parsed arenas.

## Concrete source changes

1. `CompilerAssets`: enumerate and load the fixed source closure using the same
   executable-relative path and owned-file cleanup discipline as existing assets.
   Validate the installed support interface before output publication. Extend
   support path enumeration so every source input is protected against aliases
   and replacement. Build scripts copy these exact checked-in source files.
2. `ProjectSyntax.ParsedModule`: retain validated lookup-domain provenance.
   Existing parsed project modules initialize it to the project domain.
   The trusted asset-loading path assigns the private domain only after a
   successful ordinary parse. Arena merge preserves module source locations.
3. `DeclarationBinder`: include domain in module declaration/index lookup;
   restrict `ResolveType`'s cross-module search; restrict startup selection to
   the project domain. Preserve same-domain duplicate checks and private access.
   `TryBuildIndex` must rebuild the same domain-aware keys as initial binding.
4. `ExpressionBinder`: restrict unqualified module scans and module/package
   qualification to the caller's domain. This applies to constants and bounds
   as well as executable expressions. Do not introduce a second binder.
5. `NativeLowering`/`NativePlanning`: validate required support roles, plan one
   combined program, and carry role symbol IDs to generated calls and startup.
   No second LLVM text concatenation with overlapping `ube.proc.N` identities.
6. `CompilationRequest`: retain support source diagnostic paths separately from
   manifest paths or extend the aligned module/path records together. Existing
   indexing of `Paths(BindingError.ModuleIndex)` must never access beyond the
   project-source records when a support diagnostic is reported. Input/output
   collision checks include both sources and fixed binary assets.
7. Bootstrap compilation follows the same visibility, role validation, combined
   identity and support-path rules. It cannot supply unrelated native text
   algorithms in place of the ordinary UBE implementation.

Preserve request ownership throughout. Loading or binding failure must publish
no partially merged program and must leave prior IR/executable artifacts intact.
The combined plan uses the same checked storage and index representations for
project and installed support sources. Account for both domains when diagnosing
allocation failures or remaining traversal/representation limits; installed
support does not receive an independent heap allowance.

## Runtime installation and initialization

Install the validated collector entry in the program context before any user
module initializer or managed allocation can run. Collector entry and its
dependency closure must require no allocating module initializer before they
can service allocation pressure. Reject an installed support closure that
violates this bootstrap condition, rather than running uninitialized state.

Support code shares the program's heap, thread state, precise roots and error
contracts. It is not a separately initialized native library or another program
context. Ordinary calls into support retain managed argument and return handoffs.
Collection callbacks use the runtime's documented nonrecursive collection mode.
Private support module state, if admitted later, is part of the same exact
global-root/layout plan and ordinary shutdown accounting.

## Public Text APIs

Automatic language support does not make `Text.Length`, `Text.FromUtf8`, or
`Text.ToUtf8` names visible to source programs. Their ordinary library module is
included through the currently supported explicit Source mechanism or, when
implemented, normative explicit Reference processing. Do not claim Reference
support merely because the compiler can load its own support assets.

The public library and compiler-selected operations reuse authoritative UBE
source algorithms. Public Text bodies call irreducible managed storage and
publication primitives directly; they do not call into the private lookup
domain. For example, Length reads the stored scalar count, while FromUtf8
validates a byte span through Utf8 and constructs a private candidate through
the documented managed primitives. Private concatenation/comparison routines
use those primitives and ordinary helper procedures in their own closure.

Helpers such as Utf8 or InvariantNumbers may consequently have a bound instance
in each domain when explicitly included by the user and also required by target
support. This does not duplicate their authoritative source implementation or
create a second heap: both instances operate on the same program context.
Removing duplicate generated helper bodies is an optimization only when ordinary
visibility, initialization and state semantics make sharing provably safe.

Do not introduce an algorithm-dispatch Intrinsic as a bridge. Language-spec.md
section 6 reserves Intrinsic for irreducible facilities, explicitly excluding
string algorithms, conversions and collection logic. Exact single-instance
library identity across domains would instead require a genuine package/link
implementation; it cannot be approximated by recognizing a Text procedure name.

## Required acceptance evidence

- A program declaring String works with no manual collector registration or
  implicit source reference. A numeric-only program has no unresolved collector
  symbol when its managed support is omitted.
- User modules and procedures named identically to support declarations compile
  and behave normally. Attempts to reach the private domain by unqualified,
  module-qualified or package-qualified names fail. Support attempting to bind
  a project-only member also fails. Same-domain duplicate diagnostics remain.
- Missing, malformed and wrong-signature support produces controlled located
  diagnostics; previous IR and executable hashes remain unchanged. Repeat with
  source corruption after a successful request, then repair and recover.
- Working-directory changes cannot substitute support. Output aliases to each
  installed source asset are rejected, including canonical-path aliases.
- Combined module/symbol limits fail without partial publication or out-of-range
  diagnostic-path access. A support-source error identifies its actual file.
- O0/O2 module initialization requiring String allocation has a working collector
  before entry; allocation pressure and callback recursion use the runtime gates.
- Sequential and concurrent requests produce deterministic complete plans and
  outputs. Successive self-builds exercise installed support packaging and
  bootstrap/production parity, not repository-working-directory fallback.

These are acceptance requirements, not claims that the implementation passes.

## Infrastructure evidence, 2026-11-20

`ProjectSyntax.TryAppendModuleInDomain` retains trusted domain provenance,
rejects invalid domains and permits equal module names only across domains.
The ordinary append API remains project-domain-only. `ProjectLoader.TryAppendSupport`
loads an ordinary Library manifest into the same arenas and aligned path table,
preserving the project's committed prefixes/counts on failure. The general
syntax helper `TryAppendLibrarySources` does not grant reviewed installed-source
identity; strict `TryAppendSupport` requires the compiled source count and every
ordered source identity. CompilerAssets
recognizes fixed installed path `support/Managed.UBE`. The compiler request now
selects support from retained String type/literal, concatenation, suffix or
explicit Managed primitive syntax, before preparing output. Role validation
runs before native planning; precise managed emission is a separate requirement.

The fixed reviewed closure is `managed-support-sources.txt`, packaged by
`package-managed-support.ps1`. It copies authoritative bytes, records hashes,
and generates an ordinary installed manifest; no model/test sources are included.
Compiler build packaging now installs this closure automatically. Numeric-only
requests can run without these optional managed sources. When the manifest is
present, output protection reads it as metadata and protects all its existing
source files without adding their declarations to numeric-only programs.

Commands and passing evidence under the system temporary directory:

- `bootstrap/tests/declaration-binding/append-check.ps1 -BootstrapExe <cf7c9be7 seed>`:
  56 O0/O2 append groups, now also checking same-name coexistence across domains,
  same-domain rejection, invalid-domain rejection and corrupted-domain refusal.
  Evidence `ube project append a2f19875-b323-44a2-9be6-2f962a03af42`.
- `bootstrap/tests/project-loading-ube/check.ps1 -BootstrapExe <bafe0549 seed>`:
  15 existing loader cases and all 155 allocation sites/retries at O0/O2;
  six added support cases cover colliding project names, missing manifest/source,
  malformed tail, same-domain duplicate, non-Library refusal, exact retained
  prefixes, aligned paths, recovery, and balanced owners. Changed-byte negative
  control also passes. Evidence `ube project source 59ecddfd-fa09-42bb-8c63-1c1f14a763ad`.
- `runtime/tests/managed-text/support-package-check.ps1`: nine exact ordered
  source copies/hashes, refusal of existing destination, missing source and
  escaping entry, plus a changed-byte negative control. Evidence
  `ube support package a63149db-5e98-49c4-95b7-cd04773ec8f5`.

- `runtime/tests/managed-text/support-roles-check.ps1 -BootstrapExe <bafe0549 seed>`:
  14 cases at O0/O2 validate exact bound role IDs despite colliding public names,
  folded spelling, numeric-only empty plans, missing/private/wrong-signature
  declarations, body presence, initialization refusal, failed-plan preservation
  and the authoritative Text/ManagedMemory declarations. A changed expected
  role ID fails the independent oracle. Evidence
  `ube managed support roles cdf6b20c-eec0-4ade-9157-e008eb38fff6`.

`ManagedSupport.RolePlan` contains eight numeric bound identities, carried in
NativePlanSummary and each worker's EmissionState. There is no shared global
role cache or native algorithm-dispatch intrinsic. Resolver diagnostics use
code 8 with reasons 80 (invalid facts), 81 (missing role), 82 (signature/body),
and 83 (unsupported support module initializer). NativeLowering uses reason 84
for invalid private source provenance.

Expanded evidence:

- Role gate `844ca9d0-e981-4880-be5e-e3a773425394`: 14 role cases, eight
  syntax-selection cases, and 14 actual UBE source-identity cases at O0/O2.
  Identity cases include all nine sources, changed byte, same-sum permutation,
  LF/CRLF equivalence and invalid identity.
- The expanded rerun `2ce6c4ad-7fe6-4bdb-8cae-757fe5c3dc6a` also passes
  twelve private-project provenance cases at O0/O2: valid complete source spans,
  invalid domain/count/offset/length, missing/reordered closure and numeric-only
  absence. This directly exercises the helper called by NativeLowering.
- Loader gate `54eadedd-e949-4248-a7ff-f5c97937c6a5`: the original 15 cases
  and 155 fault/retry sites pass again; nine append cases now include the
  complete reviewed closure, wrong source count and altered source rejection,
  with exact prior-prefix preservation and successful recovery at O0/O2.
- `runtime/tests/managed-text/support-install-check.ps1 -CompilerExe
  <ube managed collection compiler stable/UBE.exe>` passed ten
  installed-path protections and a hard-link alias, optional numeric assets,
  missing and corrupt managed assets, retained IR and executable and exact recovery.
  Evidence `ube support install a93185e9-ea73-460c-ae7f-2b2c61edb499`.
- `runtime/tests/managed-text/managed-roles-check.ps1 -BootstrapExe <bafe0549 seed>`:
  75 O0/O2 cases qualify all 20 managed/text/collection primitive declaration roles, exact
  IDs, renamed declarations, wrong arity/passing/rank/types/role names, unchanged
  failed role maps and an independent changed-ID negative control. Evidence
  `ube managed primitive roles 4f613ad8-e1b2-4782-abd9-a3b236f68874`.
  These tests bind declarations; they do not execute the managed primitives.
- Support role gate `e6d4c1d7-9531-444b-adc7-12c16a0ecbdb` reruns the fourteen
  role cases, fourteen source identities and twelve provenance cases at O0/O2,
  adding exact `Memory.Collect` support selection and longer-name refusal
  (ten syntax-selection cases total), plus its changed-role negative control.

These gates establish append/loading/packaging and role-resolution properties.
Binding isolation is tested by the expression-binding owner; working String,
runtime dispatch and final
self-hosting remain separate and are not established by these results.
