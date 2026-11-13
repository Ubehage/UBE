# Counted Windows command-line arguments

Run the source-to-native gate with the qualified VB6 bootstrap and installed LLVM:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/windows-arguments/check.ps1 -BootstrapExe <bootstrap-executable>
```

The gate compiles the actual `WindowsArguments` UBE source with its portable
buffer, file and UTF-8 dependencies. Both O0 and O2 execute the same assertions.
No shell interprets the tested argument text. Every child has a 60-second deadline;
native output must have an AMD64 PE header. Source snapshots, generated LLVM,
executables, diagnostics and observed byte files remain in the printed directory.

## Appending an argument

`TryAppendQuotedArgument(Source, Start, Count, Destination, Used) As Boolean`
appends one always-quoted argument to zero-based counted Byte storage. The caller
supplies any separator. `Start` and `Count` select source bytes; `Used` selects
the destination offset and is advanced only after success. NUL is invalid. The
encoded argument is bounded to 131,072 bytes and must fit the existing destination
capacity. Invalid negative counts report Err 5; out-of-range slices or insufficient
capacity report Err 9. Source and destination may be the same array: temporary
storage retains the source before publishing the quoted bytes. Failure preserves
the destination and Used. Success preserves sticky Err.

Fifteen independently authored exact-byte vectors cover empty text, ordinary text,
space/tab, quotes, backslash runs before quotes, trailing backslashes, UTF-8,
a nonzero source slice and overlapping source/destination. The UBE probe compares
each byte before writing its observed result. PowerShell compares those bytes
again, joins them into a command line and passes it to Windows
`CommandLineToArgvW`; the resulting sequence must equal the original arguments.

Ten refusal cases assert status, Err, Used and every pre-existing destination
cell. They include invalid slices, NUL, insufficient capacity and a failed scratch
allocation plus its failed retry. A subsequent append succeeds, and native
context disposal leaves zero observed live allocations. Changing runtime source
bytes while retaining the expectation must produce exact assertion exit 99.

## Reading a raw command line

`TryReadArgument(CommandLine, Requested, Destination, Found) As Boolean` reads
one zero-based argument from nonempty raw command text. Input must be valid UTF-8,
contain no NUL and have at most 131,072 bytes. A negative requested index or invalid
input reports Err 5. Executable spelling at index zero follows Windows' separate
first-argument handling. Successful lookup atomically replaces Destination and
sets Found. A missing index succeeds with Found=False and preserves Destination.
Failure preserves both Found and Destination. Successful calls preserve sticky Err.
CommandLine and Destination may alias; the named positive alias case exercises
this with a quoted argument containing a space.

The Windows oracle supplies expectations for every suffix of length zero through
five over `a`, space, backslash and quote after `app `. Every present argument and
the first absent argument are checked. Additional cases cover leading whitespace,
tabs, empty executable spelling, quoted executable names, unmatched executable
quotes, embedded quotes in an unquoted executable spelling and UTF-8 text.
The native UBE probe compares exact UTF-8 output, Found and sticky Err.

Separate invalid cases cover empty input, a negative index, NUL, malformed UTF-8
and 131,073 input bytes. The allocator observer independently fails each of the
three observed allocations and its retry, requiring preserved outputs and Err 7.
Recovery succeeds and disposal leaves zero live blocks. A changed raw executable
spelling must fail the unchanged oracle with exact exit 100. These observations
qualify the tested command-line policy; they do not establish process launch,
project loading or self-hosting.
