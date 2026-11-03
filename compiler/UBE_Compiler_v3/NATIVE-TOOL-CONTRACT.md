# Native tool invocation contract

This selects the Windows tool boundary for the existing native-executable
deliverable. It is a design contract, not evidence of a production launcher.
Compile/link commands and the explicit support/environment cohort remain in
`NATIVE-EXECUTABLE-CONTRACT.md`; diagnostics remain in
`NATIVE-BUILD-DIAGNOSTICS.md`. `NATIVE-PATH-CONTRACT.md` selects the common
path domain and acquisition sequence; production qualification remains required.

## Inputs, identity and trust

The compiler installation explicitly identifies Clang, LLD and their admitted
non-OS dependencies. Open and bind each selected executable and its path chain
before hashing, and keep its read-only-sharing file guard and path guards until
the invocation and contained descendants have stopped. Hash the held object,
not a later pathname lookup. Hold LLD's identity independently of the Clang
driver. Supply the full Clang path as non-null `lpApplicationName` and the full
LLD path through the already selected `--ld-path`. Failed guards or unqualified
path acquisition produce a precommit failure; never fall back to ambient PATH
discovery or an unguarded pathname. An image pathname alone is not proof of
which recorded bytes ran. The controlled substitute-tool tests must establish
the selected image at the actual launch boundary.

This is a trusted compiler-toolchain and operating-system boundary, not a
sandbox for hostile tools or a defence against process injection or privileged
modification of process memory. The Windows loader, API-set/KnownDLL resolution
and OS components are host prerequisites. Record the supported OS/tool cohort;
do not freeze or lock the whole Windows DLL graph on every build. Any non-OS
DLL required by a tool must be an explicit cohort member with reviewed loading
and identity rules. The PATH allowlist alone does not control DLL loading;
[Windows considers several other resolution mechanisms](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order).
Qualify mappings and sharing behavior for the admitted host/filesystem, rather
than presenting a file guard as universal protection against byte changes.

This replaces earlier open-ended wording about complete tool/DLL identity with
the stated provenance and executable-binding scope. It does not relax binding
the inspected generated input/candidate to what is compiled or published.
Source files remain ordinary read inputs: no source-consistency guards,
monitoring or source-change failures are introduced.

Use the selected allowlisted Unicode environment and owned working directory.
No shell is invoked. The qualified driver is responsible for its own child
argument serialization. It may create an internal response file in the owned
working/TEMP directory when needed for LLD, provided the cohort's independent
long-command test establishes the expanded arguments and selected linker.
Account for that temporary and its writers/cleanup within the same Job and
build ownership. No source-supplied response file or ambient configuration is
admitted, and UBE does not silently convert an oversized public tool invocation
into a response file. Driver-internal temporary storage has the same post-write,
non-quota distinction as other external tool storage.

## Argument encoding and limits

Decode input text strictly to Unicode scalar values and encode UTF-16 without
normalization. Reject embedded NUL, invalid UTF-8 or isolated surrogates before
launch. Validate path syntax separately from ordinary argument text. Use a
writable command-line buffer, as required by
[`CreateProcessW`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw).

| Quantity | Selected initial maximum |
| --- | ---: |
| Argument tokens, including argv[0] | 1024 |
| Encoded command line, including argv[0], separators, escaping and final NUL | 32767 UTF-16 code units |
| Explicit environment block, including separators and final double NUL | 32767 UTF-16 code units |

The command-line ceiling is the Windows API limit. The token/environment caps
are engineering choices, not language limits or measured process-memory bounds.
Internal callers/tests may lower them; no new public option is added. Count
encoded sizes with checked arithmetic before allocating or launching. Surrogate
pairs count as two code units. All invocation buffers and temporary expansion
storage have explicit owned payload charges, separate from the lowering cap.
Exhaustion reports UBE1502/`tool-arguments`, with no tool launch or publication.
Do not truncate, split or invoke a shell to work around a limit.

Quote the valid executable pathname as argv[0], respecting its special program
name parsing. For argv[1..], always use surrounding double quotes, including
for an empty string. Within an argument, copy ordinary characters literally;
for n backslashes immediately before a literal quote, write 2*n+1 backslashes
then the quote; for n trailing backslashes, write 2*n before the closing quote;
copy other backslashes unchanged. Separate tokens with one ASCII space.
These follow the [Microsoft CRT parsing rules](https://learn.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments);
the actual Clang/MinGW and Clang-to-LLD paths still require round-trip tests.
Absolute compiler-owned input/object/output paths are passed as distinct data
arguments so leading user filename characters cannot become options or `@` files.

## Lifecycle and deadlines

Use one external invocation at a time in the initial serial lowering/link path,
scheduled by the existing controller. No second worker pool is introduced.
The following internal defaults use monotonic elapsed milliseconds, not wall
clock time; tests may supply smaller nonnegative values. Zero means immediate
expiry, never an infinite wait. Check arithmetic and elapsed time after every
blocking API returns. These limits bound controller waits and decisions, not
the duration of arbitrary OS calls or a hard real-time return guarantee.

| Interval | Default | Starts / ends |
| --- | ---: | --- |
| Invocation | 600000 ms | Immediately before process-creation attempt until direct result, Job-empty and stream completion are established |
| Completion grace | 5000 ms | Direct-child successful exit until Job-empty and both stream EOFs; also capped by remaining invocation time |
| Failure stop/drain | 5000 ms total | First cancellation, timeout or failure requiring stop; one shared deadline for the Job and both streams |
| Controller wait slice | At most 50 ms | Every process/pipe observation iteration, also capped by the applicable remaining deadline |

Do not restart a deadline for each descendant, stream, read completion or retry.
The allowed observation interval is half-open: elapsed time equal to the limit
has expired. Check expiry before accepting a newly observed completion; a
previously latched complete result is not retroactively revoked. Thus an event
first observed exactly at the deadline follows the timeout/stop path, and a
zero invocation limit prevents launch. Use the same rule in clock-seam tests.
Check cancellation before launch, before resume, in each observation iteration
and before commit. A nonzero child result is a failure immediately; it does not
earn a fresh success-grace interval. If multiple externally timed events race,
retain the first observed primary outcome under the existing diagnostic policy;
cleanup failure is secondary. Do not overwrite cancellation with the exit code
caused by terminating the tool.

1. Prepare all bounded arguments, environment and owned handles. Create the
   tool suspended using `CreateProcessW`, Unicode environment, no new window,
   extended startup info and an explicit inherited-handle list. Only the EOF
   input and the two output write handles are inheritable. The input is an
   inheritable read handle to `NUL`, not the user's stdin or an invalid handle.
2. Create an owned kill-on-close Job without either breakaway permission.
   Assign the suspended process before resume. An incompatible enclosing Job,
   setup failure, expired deadline or cancellation prevents resume. Terminate
   and observe the suspended process on setup failure; if that cannot be
   confirmed, return failure with cleanup unconfirmed. Do not request breakaway
   or run uncontained as a compatibility fallback.
3. Resume only after containment and capture are ready. Drain stdout and stderr
   concurrently, preserving each first 4096 bytes and a separate truncation bit.
   Drain excess bytes without retaining them. A zero exit alone is insufficient:
   require observed empty Job, both EOFs and no outstanding owned writer before
   candidate inspection. [Jobs normally include CreateProcess descendants](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects);
   the qualified tool cohort must not delegate work through an external broker
   or service outside that Job. Job containment is not a hostile-code sandbox.
4. On cancellation, timeout, capture/observation failure or failed child status,
   request termination of the owned Job immediately and apply the shared
   stop/drain deadline. A termination request or closing a Job handle does not
   prove exit. Observe direct-process termination, Job-empty and completed
   capture independently. Report UBE1511 with the relevant existing observation
   category for timeout/wait/capture/drain/containment failures; preserve an
   already observed cancellation or child failure as primary.
5. If completion cannot be confirmed, never publish and never claim complete
   cleanup. Retain structured survivor/partial-stream information, preserve the
   primary result and append UBE1511/`containment` when stopping the tool cannot
   be confirmed and that observation is not already the primary failure. If
   process termination/Job-empty are confirmed but capture I/O cannot finish,
   use secondary UBE1511/`drain` instead. Containment takes precedence when both
   remain unknown; do not emit duplicate observation failures for the same stop.
   Include its current capture-state details. Report retained temporary paths
   separately with UBE1510 when delivery is possible. Do not delete
   files while an unconfirmed owned writer can still use them. Required cleanup
   and successful publication remain distinct states under the main contract.

## Capture ownership

Select cancellable overlapped pipe reads for the production boundary, not an
unbounded join of synchronous reader threads. Use two local pipe instances with
unique owned names, explicit access/inheritance, and one 4096-byte read request
buffer per stream. Retain the two 4096-byte diagnostic prefixes separately.
Process at most one completed read from each stream before checking cancellation
and deadlines again; a continuously noisy tool must not starve that check.
Pipe kernel allocation, request records/events and rendered diagnostic storage
are accounted separately from these 16384 payload bytes.

At stop, request cancellation of outstanding reads and observe each completion.
[`CancelIoEx` is a request, not completion](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelioex).
Never free/reuse a request buffer, OVERLAPPED record or its owner while I/O can
still refer to it. If stop/drain expires, transfer the unresolved invocation
owner to retained external-operation state owned by the build controller, with its
resources still charged. Admit no further external invocation until that owner
has been reaped; later builds in the same process fail tool admission with the
unresolved owner's `containment` or `drain` category. This bounds retained uncertain
state to one invocation rather than leaking another owner per build. It is a
failure state of this boundary, not a separate executor or background pool.
Reaping uses the same finite observations and releases each resource once.

## Independent acceptance

A read-only direct-import inspection of the current tool cohort used:

```powershell
rtk proxy 'C:\Program Files\LLVM\bin\llvm-readobj.exe' --coff-imports 'C:\Program Files\LLVM\bin\clang.exe'
rtk proxy 'C:\Program Files\LLVM\bin\llvm-readobj.exe' --coff-imports 'C:\Program Files\LLVM\bin\ld.lld.exe'
```

Clang's import descriptors name KERNEL32, ADVAPI32, ntdll, VERSION, OLEAUT32,
ole32 and SHELL32; LLD names the same set except VERSION (each with `.dll`).
No non-OS DLL name appears in these direct descriptors. This is not a complete
transitive/dynamic-load inventory or proof of actual loaded-module identities.
SHA-256 identities for that inspection:

| File | SHA-256 |
| --- | --- |
| clang.exe | `F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263` |
| ld.lld.exe | `8D1DD3BA3A3810AFC78A8BD97406B30BC5B9C301F9238224D35D030B0A826680` |
| llvm-readobj.exe | `C6716B20621C408580DD02CD8BE67AE8885FCC533546157396ADCD556169C59D` |

The existing tests in `JOB-CONTAINMENT-EVIDENCE.md` and `FAILURE-ORACLES.md`
establish particular host observations; they do not qualify this production
state machine, overlapped capture or selected deadlines. Before release, run
their confirmed fault/negative controls through the actual compiler boundary.
Check pre-resume cancellation/setup failure, direct success with a live writer
descendant, simultaneous noisy streams, zero and partial capture, timeout,
failed termination, missing EOF and delayed I/O cancellation. Include completion
just before/at/after each deadline with a controlled monotonic clock/event seam,
and confirm no repeated grace reset, no early validation, no freed pending
buffer and no second admitted invocation while cleanup is unresolved.

Transport controls include empty/space/tab/quote arguments, 0..3 backslashes
before quotes and at the end, BMP and supplementary characters, and an argument
containing a shell marker which must never execute. Independently test encoded
lengths 32766/32767/32768 including NUL, token counts 1023/1024/1025, environment
length limits, invalid encodings/NUL and inputs whose escaping crosses the
limit. Verify the actual Clang-to-LLD expanded argument vector and identity at
near-limit lengths, including any driver-internal response file. A generic CRT
probe or an earlier `-###` trace is insufficient for that second hop.
