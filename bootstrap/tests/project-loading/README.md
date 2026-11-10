# Bootstrap project-loading acceptance gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1
```

The runner builds `bootstrap/UBE-Bootstrap.vbp` using the installed VB6 compiler
with `/make`, `/out` and `/outdir`. VB6 may need execution outside the restricted
sandbox because of its registry access. It does not change registry settings.
An already built executable may instead be selected with `-BootstrapExe`:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe 'C:\path\UBE-Bootstrap.exe'
```

All builds, fixture files, stdout, stderr and compiler logs stay in a unique
temporary directory whose name includes spaces. The directory is printed and
retained after success or failure. Child processes are hidden, their handles
are retained before waiting, and each receives a 30-second deadline. Fixtures
use explicit UTF-8 encoding; malformed-byte cases are written as bytes.

## Assertions

Successful `--check <project.UBE>` runs must exit zero with empty stderr and
exactly these stdout lines, in order:

```text
PROJECT <project name>
MODULE <first module>
MODULE <next module>
CHECK OK
```

The positive cases cover three modules in manifest order, nested relative
paths, invocation from an unrelated working directory, spaces in paths, UTF-8
BOMs and Unicode source comments, filenames containing U+9000 and the U+1F680
surrogate pair, case-insensitive setting keys, omitted
optimization/debug settings, and Library projects without Startup. The checked-in
`bootstrap/examples/multi-module/Demo.UBE` sample must load Program then Arithmetic.
Repeated loads must have identical output; a valid invocation must also succeed
after a separate rejected invocation. This does not test reuse inside one process.

Negative cases require exit 1, the expected diagnostic category, and no CHECK OK.
Quoted syntax and invalid source-header cases also assert the filename and
one-based line number in the diagnostic.
They cover missing/escaping/absolute/duplicate source paths; duplicate module
identities and scalar keys; unknown keys; malformed quoted values and UTF-8;
missing source headers/identities; source kind/extension and version errors;
unknown and malformed reserved attributes in the source envelope;
empty manifest/source; required fields; invalid project kinds and Library
Startup; NUL source text; an NTFS junction escaping the project tree; and explicitly
unsupported references/resources/startup forms. Temporary junctions are retained
with the evidence, and point only to another generated fixture directory.
CLI misuse requires exit 2 and `E_USAGE`.

Bounds cases reject manifests above 64 KiB, individual sources above 1 MiB,
aggregate sources above 8 MiB, more than 128 sources, and module identifiers
longer than 128 characters. Exact 1 MiB sources and exactly 128 modules must pass.
These are bootstrap input limits, not language limits. Omitted settings are
accepted, but their internal default values are not exposed by this CLI and are
not asserted by this gate.

The loader currently admits only native `.bas` MODULE envelopes. Passing the
gate proves the listed project-loading outcomes only. It does not prove UBE
statement parsing, semantic analysis, procedure entry resolution, error
lowering, native code generation, full Unicode identifier support, or a
self-hosting compiler. A successful check is never a successful build claim.
An acceptance fixture contains attribute-like text after the body starts to
assert that the loader leaves body syntax uninterpreted; this fixture is not
claimed to be a semantically valid UBE program.
