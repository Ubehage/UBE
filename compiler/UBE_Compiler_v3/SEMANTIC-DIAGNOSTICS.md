# Bounded semantic check diagnostics

This fixes concrete CLI behavior before integration of the approved
SEMANTIC-CONTRACT.md subset. It adds no source syntax, executor, executable
backend or complete-language acceptance claim. The checker and these diagnostic
paths must pass their independent native/process gates before replacing UBE1012.

## Command result and retained frontend

Keep the qualified argument grammar and worker budgets in PROJECT-DIAGNOSTICS.md.
Source-only checking uses one worker budget and still rejects project-only
options. Project syntax/semantic work reuses the same admitted 1..4 budget;
all parse workers finish before semantic work can use its slots.

An entirely checked bounded input exits 0 with empty stdout/stderr and creates
no executable, intermediate or sidecar output. Invalid, deferred, cancelled,
resource-limited or otherwise unfinished checking exits 1. Usage/argument
transport retains exit 2 and its exact existing output. No new CLI optimization
switch is introduced; required integer folding applies unconditionally.

Every earlier input/envelope/scanner/parser/project failure keeps its existing
code, wording, ordering and format. A deferred frontend never enters semantic
work. Once the bounded checker qualifies, remove UBE1012 only from the paths
that actually performed the complete check. Do not report an unsupported body,
unused declaration or reference as successful language validation.

## Semantic messages

These are compiler messages, not UBECore error codes. Symbolic classes remain
the authoritative observations in independent semantic fixtures. List order in
definition.json, rather than the numeric code, breaks a same-location tie.

| Symbolic class | Code | Exact message |
| --- | --- | --- |
| MissingType | UBE1401 | declaration requires an explicit type |
| DuplicateName | UBE1402 | duplicate declaration name |
| SuffixMismatch | UBE1403 | type character does not match the declared type |
| UnknownType | UBE1404 | type name is not declared |
| InvalidType | UBE1405 | declaration or type is not valid in this context |
| UndeclaredName | UBE1406 | name is not declared |
| AmbiguousName | UBE1407 | name is ambiguous |
| InaccessibleName | UBE1408 | declaration is not accessible |
| InvalidCallTarget | UBE1409 | target is not a callable procedure |
| ConstantRange | UBE1410 | constant value is outside its selected integer range |
| ConstantDivisionByZero | UBE1411 | constant integer division by zero |
| InvalidOperator | UBE1412 | operator is not valid for these operand types |
| NotConstant | UBE1413 | expression is not a permitted constant |
| NotAssignable | UBE1414 | target is not writable storage |
| InvalidAssignment | UBE1415 | assignment form is not valid for this target |
| TypeMismatch | UBE1416 | value type is not compatible with the destination |
| InvalidByRef | UBE1417 | ByRef requires writable storage of the exact parameter type |
| InvalidArguments | UBE1418 | arguments do not match the procedure signature |
| InvalidParameters | UBE1419 | invalid parameter declaration |
| InvalidTerminator | UBE1420 | procedure terminator does not match its declaration |
| InvalidExit | UBE1421 | Exit does not match an enclosing construct |
| InvalidEntryPoint | UBE1422 | executable requires one parameterless Sub Main or Function Main As Long |
| ImplicitTypingDisabled | UBE1423 | implicit typing is disabled |
| InvalidOption | UBE1424 | option value is not valid |
| InvalidPrimitive | UBE1425 | invalid primitive declaration or binding |
| DeferredFeature | UBE1400 | semantic facility is not implemented |
| DeferredLiteral | UBE1430 | literal semantics are not implemented |
| DeferredLocalLifetime | UBE1431 | local declaration lifetime case is not implemented |
| DeferredOperator | UBE1432 | operator semantics are not implemented |
| DeferredType | UBE1433 | datatype semantics are not implemented |
| DeferredRepresentation | UBE1434 | native representation is not implemented |
| DeferredPrimitive | UBE1435 | primitive semantics are not implemented |

Infrastructure dispositions stay separate from invalid programs and deferred
language capability:

| Disposition | Code | Exact message |
| --- | --- | --- |
| Invalid caller/domain | UBE1426 | invalid semantic checking request |
| Caller budget | UBE1427 | semantic resource limit exceeded |
| Storage/root admission | UBE1428 | insufficient semantic storage |
| Cancellation | UBE1429 | semantic checking was cancelled |
| Worker admission | UBE1436 | cannot start semantic worker |
| Worker completion observation | UBE1437 | cannot wait for semantic worker |

The initial rootless command-dispatch fallback remains the existing project
storage line when execution could not enter the command handler at all. Once
semantic work or formatting is selected, its allocation-free fallback is exactly
`error UBE1428: insufficient semantic storage` plus LF. Never format an ordinary
semantic diagnostic from stale Err or overwrite it with a formatter's failure.

## Source locations, formatting and ownership

Each complete standalone semantic diagnostic is one header followed by the
original one-based line, one-based scalar column and zero-based byte offset,
each on its own line with LF separators:

```text
error CODE: MESSAGE (next lines: line, column, byte)
LINE
COLUMN
BYTE
```

A project semantic diagnostic first includes the owning source's escaped path
line, in the exact quoted UTF-8 form from PROJECT-DISPLAY-CONTRACT.md, followed
by the same four lines. Source-independent infrastructure failures use the root
invocation path and position 1:1:0. No input path lookup, source String copy or
Unicode normalization is introduced. A source-independent standalone fallback
uses the same 1:1:0 point. Retain the exclusive end span in structured results;
the CLI does not pretend a byte offset is a column or fabricate a displayed range.

Keep the admitted input/syntax owner graph alive until all position/path
preparation and output finish. The primary and optional related spans remain
original source spans. DuplicateName's related span is the first conflicting
declaration; related spans are not printed by this initial CLI format. A missing
entry point anchors root source EOF; a second entry anchors its name; wrong
signatures anchor the candidate name, as fixed in SEMANTIC-CONTRACT.md.

Prepare the entire diagnostic, including a project path when needed, before
printing anything. Any managed admission/allocation/format failure prints only
the static semantic storage fallback. Preserve the underlying structured
diagnostic and old semantic result/owners throughout failure. All admitted
workers drain and all external resources retain the qualified close/cleanup
behavior before command return.

## Acceptance procedure

The maintained native/process gate must check complete exact stdout, stderr,
exit status, original coordinates and absence of output artifacts through both
accepted source-built stages. Include a checked minimal Sub and Long Function,
known constant folding/conversion, every error/defer class above, source and
explicit-reference projects, canonical first-error ordering at jobs 1/2/4,
Unicode/BOM/CRLF positions, usage and all earlier frontend cases.

Inject actual formatter allocation/root failures before entry and at every
observed preparation site; require the single static fallback with no path or
partial coordinates. Cover semantic budget/domain/cancel/storage/start/wait
dispositions and later recovery, retaining old owners and structured failure.
The successful syntax-only CLI reports remain historical until these new
expectations and the actual checker pass; changing expected UBE1012 lines by
itself is not qualification.
