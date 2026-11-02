# Final generic draft sharing shape

This addendum supersedes the earlier worker paragraph's ProbeKey/ProbeIndex
prototype and exact output count. It was fixed before native execution of this
shape. The arena's48/24-byte contract is unchanged.

Use the selected ByteKeys draft's16-byte ByteKey(Partition,FirstByte,ByteCount,
Value), direct Long order vector, TryOrderByteKeys and TryFindByteKeyRange. Use
the final minimal SignedIntegers API's TryDecodeDecimalInteger and
TryEvaluateInteger, with no public metrics parameter. Integrated runs consume
these modules through the real UBECore Reference. Test-only ArenaProbe uses Core
TryGetStorageCapacity and NameProbe's scalar wrapper delegates to Core
TryEncodeUtf8Scalar. Neither fixture supplies a standalone Main.

One owner contains pairs with byte-identical names in two distinct partitions.
Ordinal i has Partition=SourceId+i Mod2 and label=ceil(N/2)-floor(i/2). A lookup
must return exactly one match in its requested partition, never both spellings.
Each of four rounds additionally queries an absent third partition, expecting
FirstMatch=N and MatchCount=0. Answers contain2*N+2 Longs. Native comparison and
key-byte-read observations are injected at the exact private query comparator
and runtime array-access boundaries, rather than adding a production metrics API.
At most8*(N+1)*(ceil(log2(N+1))+1) query comparisons occur per worker. Each key
comparison reads at most eight bytes. Final worker payload copying is exactly
8*N+14 bytes: answer-vector publication8*N+8 plus six derived name bytes.
All earlier no-source/catalog-copy, ownership, root and requested-byte bounds
remain. Numeric values are signed64 minimum and30000, and span/arena/name output
expectations remain independently specified.
