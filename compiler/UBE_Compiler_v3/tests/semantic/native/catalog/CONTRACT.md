# Private catalog native qualification contract

This gate consumes declaration preparation from the production compiler
manifest. No source-controlled native recursion, secondary source parser or
new executor is involved. The entry receives a new private
catalog with qualified retained sources. Failure discards that private catalog;
an unrelated old complete catalog and its exact source owners remain live.

Fixed native scalar layouts: declaration64, fact48, bound48, native-type40,
name24 and explicit declaration frame12 bytes. The catalog class is240 bytes
and source association64 bytes for the frozen model. Both compiler stages must
emit identical raw LLVM and the gate must inspect these actual layouts.

Declaration IDs begin with all source modules, then canonical source/member,
parameter and local order. Parameters are contiguous before locals. Source
syntax/name maps and cooked UTF-8 bytes are private geometric storage, trimmed
once; no per-name snapshot or per-append whole-table publication occurs. Catalog
lookup helpers are strictly read-only after freezing. Values/defaults stay
unknown until constant preparation. Names exclude parser-selected
type characters, unescape qualified brackets, and use pinned simple folding.
Quoted module names reuse the existing qualified identity scalar decoder.

The completed independent19-declaration fixture is an exploratory functional
probe, not final qualification. An exploratory allocation-count guard256 was
deliberately rejected by observation. Attribution identified1745 allocations
inside1744 real managed value assignments, plus32 arena/storage allocations;
small reference/receiver snapshots account for the linear managed overhead.
The inherited preset maximum512 additional roots is unchanged. This observation
does not justify a logarithmic total allocation claim or a bootstrap ABI change.

Before final cost acceptance, use these input-dependent bounds. R is actual
checked syntax-read helper entries, S actual canonical scalar encoder entries,
D/N/T/K/F the completed declaration/name/type/key/fact counts, V total admitted
syntax nodes, P maximum explicit pending frames, C source count, B canonical
byte count, A actual managed assignment calls, and L=ceil(log2(D+N+K+C+1))+1.
All observations come from actual helper/runtime boundaries, not formulas
reported as executed counters.

- A <=64*(R+S+D+C+1)+256.
- Managed allocation calls <=A+4*L; other allocation calls <=32+16*L+8*C.
- Managed requested bytes <=8*A+4*K+arrayHeader+gcHeader+64.
- Define Qcopy=5*D*64+5*N*24+T*40+5*K*16+4*F*48+5*B+4*V+4*C*P*12+4096,
  and Qmemory=Qcopy+3*K*4.
  Total requested bytes <=8*A+Qmemory+(32+20*L+8*C)*(arrayHeader+gcHeader).
  Additional peak GC payload <=Qmemory+(32+20*L+8*C)*arrayHeader.
  Array payload copying <=Qcopy, calloc zeroing <=requested bytes.
- Additional simultaneous roots <=512, independently of declaration count.
- Original source/token/syntax payload copies and resizes are zero.

These deliberately include unreclaimed geometric arrays and exact trims;
dropped references are not assumed immediately reclaimed. Reference snapshots
are separated from original source payload copying. Counts0,1,8,64,1024,16384
use independently generated variable spelling/content and canonical expected
declarations. Every actual allocation-denial site in the fixed representative
fixture must preserve old graph/owners, return fresh storage5/1428, reclaim all
temporary GC payload, and recover. Full real-backed root capacities zero through
exact-plus-one must distinguish admission failure from semantic/domain failures.
Logical budgets use zero/below/exact/above and invalid values. Physical heap
peaks use callbacks at both actual GC allocation increments; all five heap
mutation statements and every root counter mutation remain audited.

Final controls must reject a wrong declaration/type, extra declaration, corrupted
work observation, omitted heap observation and an actual forbidden source clone.
All inputs, generated projects, copied source/Core/runtime fixtures, tool/selection
identities, raw/adapted LLVM, executables and exact output must be retained.
Current diagnostic scripts explicitly keep qualifiedCatalog=false until both
stages and all these requirements have passed. No complete checker claim follows
from this component gate.

The exploratory formula initially omitted the sorted index's three exact Long
vectors: Pending and Scratch from TryOrderByteKeys, then its completed published
clone. Adding the required module metadata fact moved F from16384 to16385 and
made the fact arena use its next geometric capacity, exposing that omission.
Failed recheck97c8115e9792461fb4b9a0adbdb2d09f observed15,041,109 additional GC
payload against the incomplete14,987,137 bound. The3*K*4 correction above accounts
for those existing, separately qualified vectors; their three actual array/GC
headers are already included in the unchanged fixed32/header allowance, not
added again. No other Qcopy term describes Long order vectors:5*K*16 describes
only ByteKey records;4*V describes NameMap cells;4*C*P*12 describes traversal
frames. The copy bound is unchanged (the two working vectors are written in
place, and the one published K-Long clone fits the existing key-copy allowance).
No observed constant is fitted and the512-root/allocation-count/source-payload
bounds are unchanged. This correction precedes final acceptance.
