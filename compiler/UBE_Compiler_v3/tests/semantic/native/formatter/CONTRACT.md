# Focused semantic diagnostic formatter gate

This consumes the exact production compiler manifest, its diagnostic formatter
and common `TryFindSemanticSourceToken` procedure, accepted source-built tools
and real UBECore. It qualifies formatting; CLI dispatch and complete semantic
result construction remain separate whole-checker gate responsibilities.

The fixture admits original UTF-8 bytes through Begin/Append/FinishSourceInput,
then the real envelope, scanner and parser. Its ProjectSyntax/ProjectInput/
ProjectSource classes retain the very same source Owner. Its association is
test-owned rather than filesystem project discovery. Paths include newline,
tab, 0x01, DEL, quote, backslash and non-ASCII UTF-8. All original source arrays,
tokens, syntax and associations are fingerprinted with their owner identities.

Before acceptance, both source-built stages must produce identical raw LLVM.
Independent C expectations cover the fixed38 messages in all four format/print
forms, all qualified token coordinates with UTF-8 BOM/CRLF, unknown-code/source/
offset rejection and source-independent1:1:0 diagnostics. Complete strings have
no trailing LF; printing adds exactly one LF in one String+newline pair.

Fault admission is observed at actual malloc/calloc/realloc calls and actual
GC root-count increments. Each of the four forms is rerun with persistent
allocation denial beginning at every successful observed site. A registry
backed by the real one-million root storage slots is filled; every remaining
capacity from0 through observed peak+1 is exercised, bounded beforehand by256.
Earlier Failure fields and older output are preserved. Any failed print must
emit exactly the static UBE1428 line, with no path, header or coordinates.
All temporary allocations are collected back to the prior physical GC payload
baseline; successful recovery retains the original owner graph.

The observer is the maintained foundation observer, including its audit of all
five heap-live-byte mutations and exact callbacks at both increment sites.
No callback allocates, locks, or observes pointers through the managed API.

The initial failed diagnostic runs are retained. They caught a reversed
test-fixture path-copy call; the corrected constructor now validates actual
association bytes independently before invoking the formatter.
