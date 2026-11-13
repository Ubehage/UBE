# Compiler command options

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/command-options/check.ps1 -BootstrapExe <bootstrap-executable>
```

The gate compiles the actual `CommandOptions` module and its counted-byte Windows
argument parser dependencies. It performs no filesystem interpretation of parsed
paths and launches no command described by a test input. O0 and O2 execute the
same source assertions; each generated executable has an asserted AMD64 PE header
and a bounded execution deadline. Evidence remains in the printed directory.

`CommandOptions.TryParse(CommandLine, Options, Diagnostic) As Boolean` accepts
only these exact, case-sensitive command forms:

```text
<executable> --emit-llvm <project.UBE> <output.ll>
<executable> --build <project.UBE> <output.exe> [--clang <path>]
```

Quoting and raw UTF-8 validation use `WindowsArguments.TryReadArgument`. The
caller retains the raw command line. Arguments 2 and 3 identify the project and
output; accepted text is nonempty but is not normalized, opened or checked for
an extension here. `CommandRequest.Mode` is 1 for emission or 2 for building.
`ClangArgument` is zero when absent and 5 when supplied. No other compiler modes
are admitted by this parser.

`CommandDiagnostic.Code` is zero on success, 1 for a usage error, or 2 when an
argument cannot be read. `Argument` identifies the zero-based argument being
checked; raw-text validation failure is reported at index zero. Successful
parsing clears both diagnostic fields. Rejected commands preserve every old
Options field. Usage errors preserve sticky Err; helper failures preserve the
helper's error, including Err 5 for invalid raw text and Err 7 for allocation
failure. Request state and scratch storage are caller- or invocation-owned.

The 28 independently specified cases cover both modes, optional Clang, spaces,
tabs, Unicode, escaped quotes/trailing slashes, concatenated quoted flag spelling,
literal path spellings beginning with dashes, missing and empty arguments,
unknown/case-mismatched flags, unwanted optional flags on emission, trailing
arguments and invalid raw UTF-8/NUL/empty input. Assertions require exact status,
diagnostic code/index, request fields and Err.

The fully populated build command measures 19 allocation calls: three for each
present argument and one for the absent seventh. Every observed site and its
retry are failed separately. Each failure must retain the old request, report
the precise argument index and Err 7; parsing the same command afterward must
recover. Context disposal must leave zero observed live allocations at each
optimization level. Changing the first mode's spelling while retaining its
expected request must produce exact assertion exit 100.

This gate qualifies command parsing and failure behavior, not project loading,
backend invocation, output publication or a runnable self-hosting compiler.
