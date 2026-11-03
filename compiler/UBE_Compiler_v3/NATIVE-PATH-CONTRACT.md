# Native build path acquisition: Windows design

This selects a bounded path policy for the existing first native build. It is
not a change to the project-file grammar, the existing `--check` command, or the
eventual set of paths UBE can support. `NATIVE-EXECUTABLE-CONTRACT.md` governs
output ownership and `NATIVE-TOOL-CONTRACT.md` governs tool identity. This is a
preimplementation design: the retained host probes do not qualify the complete
walk or the production compiler.

## Initial output and tool path domain

For the output and compiler-owned tool paths, admit ordinary, case-insensitive
directories on a local fixed NTFS volume, addressed by a normal Windows drive
path. Resolve relative output paths against the invocation working directory
and the default against the project directory using Windows path semantics;
keep the original selected spelling for diagnostics. Unicode is converted
strictly to UTF-16 without Unicode normalization. Spaces, non-ASCII names,
ordinary `.` and `..` segments and existing 8.3 aliases are not rejected merely
for being present. Validate the resulting Win32 name and exact leaf before the
handle-relative operation; never interpret a name as a shell command.

For this first build, refuse UNC/network paths, device namespaces, alternate
data streams, extended-namespace spellings, drive-relative forms such as
`C:foo`, reparse points in an output or tool path, case-sensitive directories,
and a filesystem, directory or API combination for which the required identity,
name-equivalence and replacement behavior cannot be established. Do not infer
support merely from a volume's reported filesystem name. Reserved device names,
invalid encodings, malformed or unrepresentable names and unsupported path
components fail in a controlled manner. No lexical normalization may turn an
unsupported spelling into a different admitted file silently. Absolute and
ordinary relative path support remains as stated in the main contract; this
bounded native-build restriction is explicit, not a permanent UBE path rule.

An unsafe or unsupported destination produces UBE1501 and the selected
destination detail. A tool whose path cannot be acquired under this policy
produces the existing UBE1504 tool-start failure and tool-path detail, without
launch. Project and source intake continue to use the established frontend
path rules and diagnostics; these output/tool restrictions do not silently
change the meaning of a manifest or turn a valid `--check` into an error. If a
build cannot establish input/output separation from an otherwise admitted input,
it fails the native output admission with UBE1501 rather than guessing. An
explicit valid local output remains available when a default output cannot be
bound. Windows/path support and diagnostic behavior must be documented when
the build command ships.

## Anchoring and admission

Capture the invocation directory and resolve the requested output parent before
destination admission. Open the local drive root for `FILE_READ_ATTRIBUTES`
with read/write sharing and no delete sharing and retain it. Starting from that
root, use this
specific acquisition sequence for each component:

1. Open a **temporary parent guard** for `FILE_READ_ATTRIBUTES`, sharing reads
   only. It denies new write/delete access to that directory and fails if an
   incompatible existing handle prevents the guard. The root is subject to
   the same check. Validate the held parent's directory, non-reparse and
   case-sensitivity attributes while this guard is held.
2. Open the next single component relative to that held parent, opening the
   component itself without following a final reparse point. Open a **retained
   child guard** for `FILE_READ_ATTRIBUTES`, sharing reads and writes but not
   deletion. Validate the opened child as an ordinary case-insensitive
   directory and retain its identity and handle. If any open, query or
   validation fails, release acquired handles and fail; do not reopen an
   absolute pathname or follow the reparse point.
3. Release the temporary parent guard only after the retained child guard and
   its validation are complete. The held child is the nonempty-entry anchor for
   that parent. Continue from the retained child. Keep the ordered retained
   handles through publication or the tool invocation.

At the final output parent, acquire a temporary guard for `FILE_READ_ATTRIBUTES`
and `FILE_ADD_FILE` with read sharing only. While it remains held, create a
unique anchor entry relative to that guard with exclusive create, open/retain
the anchor without delete sharing, and validate that the handle is an ordinary
new file. Acquire the long-lived output-parent guard for `FILE_READ_ATTRIBUTES`
with read/write sharing and no delete sharing while the temporary guard is still
held. Release the temporary guard only after the anchor and retained parent guard
are established. Keep both through commit or abandonment. The anchor stays
separate from the tool's candidate so the candidate can later be opened with
DELETE access and renamed. Remove it as owned cleanup; a postcommit cleanup
warning does not undo a successful build.

At the final tool parent, keep its temporary read-only-sharing guard until the
selected tool file itself has been opened relative to it, validated and held
with the read-only file sharing required by `NATIVE-TOOL-CONTRACT.md`. The held
tool entry supplies the nonempty-parent condition during that invocation; no
temporary file is created in the tool installation directory. If this handoff
cannot be established, report the tool acquisition failure before launch.

When the default `build` directory is absent, acquire its temporary parent guard
with `FILE_ADD_SUBDIRECTORY` as well as `FILE_READ_ATTRIBUTES`; create the
directory relative to that guard, then retain and validate the resulting
directory as above. If another actor creates it first, inspect the actual entry
and either use that validated directory or fail; never assume a failed create
made the intended directory. A file or unsupported reparse point at that name is
a controlled output failure. Never substitute a fresh absolute lookup for a
retained parent when creating the candidate, comparing the output entry, or
committing it. Retain the output leaf separately from the pathname used for
messages. Preserve the same Windows name interpretation for admission and
rename, including existing short-name and case aliases.

This algorithm is the selected route, not a claim that NTFS or Windows has
already qualified it. If a relative open or child/anchor creation conflicts with
the temporary sharing mode, or the retained guard cannot be acquired while that
guard is held, reject the build before publication; do not release the guard
early or fall back to a pathname check. The retained metadata/no-delete guard is
the combination observed in the ordinary-path prototype, but the full handoff
above has not been tested. The bounded host model is a qualified local NTFS
cohort where a held child or anchor prevents conversion of its nonempty parent
into a reparse point, normal share checks apply to competing opens, and no
arbitrary injected handles or unqualified filesystem filters bypass those rules.
Pre-existing ordinary write/delete handles must either prevent temporary guard
acquisition or otherwise be accounted for; do not assume they vanished. If the
host cannot establish these conditions, reject it. Do not generalize a single
mount-point test to every reparse tag or filter.

These short-lived directory guards protect acquisition, not source consistency;
source file handles continue to allow read/write/delete sharing. Qualification
must also check ordinary source edits and replacement saves, including a source
in the guarded directory, and identify any transient sharing failure rather
than claiming editors can never be affected. No source monitoring or retry is
introduced.

Inputs are opened for intake with ordinary read/write/delete sharing. Capture
the identity and entry actually used by intake, including both a final link
entry and its opened target when applicable; preserve the source and project
spelling needed for diagnostics. Do not reopen an input later and call that
fresh lookup the intake identity. Inputs may use facilities admitted by the
existing project loader, including links, provided the build can establish
their relation to the admitted output entry; the output path restriction above
does not redefine their grammar. Retained input handles, if needed for identity
lifetime, keep read/write/delete sharing. There is no source monitoring,
consistency lock, change-detection failure, restart or retry.

Before tool work, compare the admitted output entry against the complete actual
input set, including manifests, sources, selected tools and support files.
Compare volume/file identities from handles for existing target and hard-link
aliases, and compare actual parent-entry identities for the original link/name
when relevant. Ask the filesystem to resolve supported names under the held
parent; do not use UBE identifier folding, `_wcsicmp`, or a guessed uppercase
table as a substitute for filesystem name equivalence. Where an identity,
entry relation, alias, or name cannot be resolved safely, fail admission. An
existing output that is an input entry or an already-present hard link to an
input is rejected. A missing output is admitted only after the same parent and
leaf have been established and it is safely distinguished from the recorded
input entries. The initial comparison is a build admission check, not a claim
that inputs remain unchanged afterward.

## Candidate, tool and commit

Create the unique sibling candidate in the held output parent with an
exclusive create, never by opening and truncating an existing entry. Ensure
owned temporary names cannot select a source or protected input. Compiler-
owned pathname arguments handed to Clang/LLD must refer to the same held
directory and objects under the tool contract's path guards; if the host cannot
establish that association, do not invoke the tool or use an unguarded pathname
fallback. Account for the tool's private temporary names and writer containment
as specified in `NATIVE-TOOL-CONTRACT.md`.

After all admitted writers have stopped, open and hold the candidate for
inspection with read and DELETE access and read-only sharing; require the
inspected object and its bytes to remain the object published. A pre-existing
writer or writable mapping that defeats that protection makes the build fail
before publication. Commit with the selected handle-relative extended rename
to the admitted parent and leaf. This replaces the output directory entry and
does not open a final output link for writing through to its target. A late
ordinary replacement or a separate hard link to an input may be replaced on
success; the compiler does not alter the unchanged input's original entry or
contents. A source deliberately moved onto the admitted output entry is subject
to the owner's output-ownership interpretation in the main contract. A failure
before successful commit preserves the then-current output against compiler
modification; it does not undo another actor's changes.

## Required qualification

The 16-case ordinary-path host probe in
`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md` supports this direction,
not the entire policy. Before release, exercise the actual compiler boundary
and its selected Windows/filesystem cohort with independent barriers and
negative controls for:

* source edit and replacement saves during a build, including when source and
  output share an ancestor; no source-lock, monitoring or retry behavior;
* existing input entries, hard links, final input links, case and 8.3 aliases,
  absent outputs, and safely rejected ambiguous names; independently confirm
  actual opened identities and parent/leaf equivalence;
* relative, drive-absolute, Unicode and spaced paths; explicit diagnostics for
  unsupported reparse, device, network, case-sensitive and filesystem cases,
  without changing ordinary project checking;
* component replacement, reparse creation/retargeting, parent moves, pre-existing
  write/delete handles and the owned anchor's lifetime, including moves before
  each acquisition step and paths shared with tool invocation;
* unique-candidate creation races, candidate swaps, pre-existing writers and
  mappings, actual tool path/object binding, late output hard links, cancellation,
  failed rename, and complete old/new reader observations and cleanup.

Require an actor-success control where the host permits a tested mutation and
an untriggered-fault control that fails its test. Explicitly report unsupported
host operations rather than treating them as successful resistance. Establish
which NTFS/Windows combinations make the no-delete guard, nonempty-parent
invariant, name lookup and relative rename safe together; held handles and a
single observed filesystem are not a general Windows guarantee. The future
build must apply the selected error and cleanup contracts on every failure.
