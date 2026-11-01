# Project CLI implementation boundary

Implements PROJECT-DIAGNOSTICS.md using TryParseProject and the existing source
CLI. Exact initial process definitions are frozen in tests/project-input/cli.json
before dispatch changes. Extend them with missing code/cleanup/formatter cases;
the initial set is not full acceptance.

Main is a rootless entry: initialize non-success status before calling a checked
managed command dispatcher. Failure to enter that dispatcher prints the static
UBE1310 fallback and returns 1. An unentered managed Main must not accidentally
return its neutral Long zero as a successful compilation. All argument/path/work
storage belongs to the checked dispatcher or its single check operation.

Project option spelling/order is exact. Source-only command shapes and output
remain covered by the existing strict process oracles. One project request calls
TryParseProject with one jobs budget and explicit limits/cancellation/token.
All workers drain before diagnostic preparation or successful-syntax UBE1012.
The CLI retries any retained file close and appends the frozen release message
if that retry fails. No new executor, lookup path, environment option or artifact.

Shared source diagnostic selectors/preparation preserve existing messages.
Prepare every fallible path/line/position before the first Print. Project codes
print header/path/coordinates; delegated source errors print path first and the
existing source diagnostic. A failed preparation prints only the static project
storage fallback and does not mutate the structured primary failure.
