# Bounded grammar consumer implementation

Status: qualified for the bounded consumer in `PARSER-CONTRACT.md`. The measured
representation decision remains `PARSER-PROBE-EVIDENCE.md`; exact current native,
CLI, failure, cost and artifact results are in `PARSER-NATIVE-EVIDENCE.md`.

## Private storage and ownership

`SyntaxTree.bas` owns the shared pending representation. Nodes have the measured
six-Long linked-child layout: kind, original first/last byte, first child, next
sibling and child count. Node indexes are private construction identities; they
need not be postorder. A parent frame retains its last child so appending children
does constant work. The production path creates nodes directly, without the
probe's command stream.

The pending one-element result array contains the owned node array, logical node
count, root and caller-provided source identity. It is prepared privately, trimmed
to its logical size, then copied with one transactional `Array.TryCopy`. That
single publication includes all owned arrays and metadata. Admission, preparation
and publication failures preserve the entire old result. Source documents and
token arrays are borrowed immutable views; the caller retains the source for the
lifetime of its returned spans. No source payload enters builtin String.

`SyntaxExpressions.bas` uses explicit precedence continuation frames for operands,
operators, grouping and postfix argument lists. `SyntaxGrammar.bas` uses explicit
control frames for statement lines, inline If association and nested blocks.
No source-controlled recursion is used. Grammar spellings use ordinary source
views and pinned Unicode folding. Reusable source, decoding, byte storage and
Unicode facilities remain in UBECore.

## Scope and entry

The token entry `TryParseSyntax` consumes qualified views and offers internal
expression, statement and native MODULE contexts for diagnostic testing. These
contexts are not a public compiler phase ABI. A syntax result does not establish
literal values, binding, types, executable validity or code generation.

The source diagnostic entry `TryParseSourceSyntax` notices pending conditional
input before requesting a complete raw scan. It returns a distinct deferred
disposition at the first directive without evaluating it or examining inactive
text. Thus the current scanner's failure on an inactive unclosed quote cannot
become a universal prerequisite for future conditional selection. Scanner and
this source-admission work are separate from parser-only measurements.

Date candidates are recognized only in expression/attribute contexts by consuming
the existing borrowed token spans, including a closing hash already owned by a
numeric suffix token. They are never converted to host dates or retokenized. In
the bounded Print context, a closing hash before a comma, semicolon or logical
newline selects a date-expression candidate; a preceding separator or unpaired
hash defers the file/formatting Print family. Invariant date spellings contain no
comma or semicolon. Locale-compatibility date selection remains outside this
consumer, rather than being silently resolved by host locale.

Unambiguous use-site type characters remain part of the original Name extent,
including member names. Established Bang members remain legal even when their
spelling is Then or Else. A private If-condition context permits bounded
following-token lookahead to distinguish `If x! Then F` from
`If obj!Then Then F`; the fragment `(obj!Then)` keeps ordinary Bang grouping.
The analogous Else context is enabled only for a statement line directly owned
by a single-line If branch with its own or a cached enclosing unmatched Else.
That availability is inherited only through immediate inline-If ownership, so
structured blocks do not expose an unrelated outer delimiter. Because Else is
optional, a final `obj!Else` remains
a member when no branch body follows. No global keyword rule, abandoned-node
reparse or unbounded alternative search implements these decisions. Ambiguous
suffix/operator forms explicitly deferred by the contract remain deferred.
In particular, the spaced `! Then` followed by an expression continuation that
can also open a statement body, as in `If x! Then (F)`, remains an unresolved
suffix/Bang-role disposition when no actual Then delimiter follows. It returns
deferred rather than a fabricated syntax error. A complete
`If obj!Then(F) Then G` retains its successful Bang/application grouping.

## Resource and measurement obligations

Source and token limits retain the existing 16777216-byte and 1048576-token
limits. Callers supply node, pending-work and syntactic-depth budgets. Depth
counts simultaneously open groups/blocks and pending prefix/right-power
operands; a tall left-associated result alone does not consume source depth.
Pending workspace is the simultaneous control-frame plus expression-frame count,
not a separate allowance for every nested helper.
`MaximumNodes` bounds all simultaneously materialized pending syntax records,
including disposable declaration/default/bound validation nodes, as well as the
published node count. It is not a promise that a small final tree requires equally
small temporary node storage. `MaximumPending` independently bounds the combined
control/expression frame workspace. These are caller-selected resource limits,
not additional language limits on declarations or expression length.
The native boundaries include 255, 256 and 257 at a configured limit of 256,
mixed precedence, wide calls, flat chains and nested control flow.

The predefined probe work/copy bounds carry forward to the actual consumer:

- Zero source-payload copies and no whole-array/subtree copy per append.
- At most `64 * (T + 1)` executed token inspections and
  `64 * (T + N + 1)` grammar/state actions, excluding separately observed
  spelling/Unicode comparisons, source admission, scanning and harness work.
- Geometric pending-node growth copying below `2 * 24 * M`, where M is the
  observed maximum live pending-node count, with the existing eight-slot
  allowance. Opaque declaration validation may discard private detail nodes;
  count those executed writes and their maximum live storage separately from
  final emitted N. For expressions without discarded detail, M=N and each node
  is written once. Exact trim plus publication is at most twice the logical
  node payload plus 64 bytes of fixed wrapper allowance. Combined output copying
  is bounded by twice maximum live pending-node payload plus twice final output
  payload and those small allowances; this is the original four-times bound
  when M=N. Discarding private validation nodes cannot hide their executed work.
- Each workspace array separately obeys geometric capacity/copy bounds for its
  actual maximum live record count and measured native stride. Actual requested
  allocation/zero initialization, live payload and generated/runtime roots are
  reported separately. Counters record executed operations; they are not
  reconstructed from input sizes. Wall time alone is not an acceptance gate.

Qualification must cover both source-built stages, the full frozen syntax,
rejection and deferred cohort, deliberate incorrect comparison controls, actual
root pressure and persistent allocator denial, complete old-result retention,
cleanup, deterministic private native workers, and identical raw LLVM.

## Logical comparison

The independent fixtures describe observable grouping, not production node
identity. The comparator validates the entire actual graph before comparing
logical node kinds, ordered children and exact original spans. A leaf Header
witness intentionally leaves header detail unspecified; its detailed children
may be omitted from that logical projection. Headers with specified children
require those details. This explicit projection does not permit dropping other
nodes, changing grouping, accepting malformed syntax or generating expectations
from production output. Opaque declaration/parameter leaves still validate their
complete syntax; disposable validation nodes are private and are not published.

Two original ordinary-call fixtures used the reserved word `text` as a bare
argument name. The owner explicitly approved replacing that source/witness
spelling with `s` in `Mid$(s,2)` and `Len(s)`. Their shapes, rule references,
case identities and ordinary-call obligations are unchanged. `Text` remains
reserved; no parser exception or language-rule relaxation implements the cases.

## Evidence

`PARSER-NATIVE-EVIDENCE.md` records the passing 501-check bootstrap refresh,
4049-check unrestricted native gate, 82 CLI cases, 54 diagnostic controls and
41 published-artifact checks. Both source-built stages pass the full contracted
cohort, all 10412 real-root capacities and 102 observed cost rows. Its exact
commands, identities and limits define this qualification; complete-language
parsing, semantic checking and code generation are not established.
