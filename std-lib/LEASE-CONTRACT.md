# Named lease primitives

`LeasePrimitives.TryAcquire(KeyUtf8(), Token, Failure)` acquires a nonrecursive,
fail-immediate operating-system reservation. The input is 1–4096 strict UTF-8
bytes without NUL. `Token` must initially be zero. A successful acquisition owns
the key until `TryClose(Token, Failure)` succeeds or the owning process exits.
Independent callers, including callers on the same thread, cannot reacquire a
held key. An existing key reports failure 19; unavailable OS access or a conflicting
object type fails without granting ownership. Ordinary file operations reject
lease tokens. A failed close leaves the token available for retry. A failed
acquisition can retain a token if closing a rejected existing-object handle fails;
callers must clean up that token despite the false result.

The current Windows target uses Global named event objects as existence leases.
It neither waits on nor signals them. It requires no persistent lockfile or
adjacent lock directory. Default Windows object permissions apply. Deliberately
precreated names or incompatible permissions can cause refusal; this is a
cooperation protocol, not a security boundary. It coordinates processes on one
machine, including Windows sessions, not different machines accessing a network
share. Cross-session and different-user execution still require dedicated
acceptance evidence.

The target normalizes UTF-16 with invariant `LCMAP_UPPERCASE`, checks that
`CompareStringOrdinal(ignoreCase=True)` considers the original and mapped key
equal, then hashes each UTF-16 unit. Hash one starts at 2166136261 and repeatedly
computes `(hash * 257 + unit) mod 4294967291`; hash two starts at 2246822519 and
uses multiplier 65537 and modulus 4294967279. The object name is
`Global\UBE.Lease.` followed by each hash as eight uppercase hexadecimal digits.
A collision causes conservative refusal and never grants overlapping ownership.
The fixed algorithm is shared with the bootstrap host. Changing it requires
coordinated compatibility handling for cooperating processes.

Output publication keys are `ON/` plus the physical parent identity's 24 hex
digits, `/`, and destination leaf; existing and staged file keys are `OF/` plus
their 24 identity hex digits and `/`. Identity is exactly the twelve bytes returned
by `File.TryIdentity`: volume serial, high file index and low file index, each in
little-endian byte order. Keeping the namespace, old inode and new inode leases
until cleanup prevents replacement from releasing ownership early. Case-sensitive
Windows directories are conservatively treated using the compiler's existing
case-insensitive path policy; distinct case-only destinations can be refused.

`bootstrap/tests/output-publication/lease-check.ps1` checks physical path aliases,
hardlinks, nonexistent targets, independent targets, release/reacquisition and
cross-process ownership. These checks do not establish immunity to arbitrary
external writers that do not use this protocol.
