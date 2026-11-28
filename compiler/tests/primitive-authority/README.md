# Checked primitive authority

Run `check.ps1 -CompilerExe <actual UBE.exe>` with its adjacent `llvm` and
`support` directories. The gate builds the complete public UBECore source
manifest plus its test program at O0 and O2. It checks invalid UTF-8, scalar-count
mismatch, destination preservation, candidate repair/retry, cross-thread
rejection, consumed/abandoned candidates, reverse-order custom construction,
supplementary text, embedded zero, and ordinary Text.FromUtf8 packaging.

Restricted-role exact declarations, renamed declarations and copied support
modules must fail before publication. Altering installed source bytes must also
fail without replacing an earlier output. A changed expected String must fail
the executable oracle with its exact assertion code. Evidence stays in the
printed temporary directory.

`runtime/tests/managed-text/managed-roles-check.ps1` independently exercises the
actual binder at O0/O2, including forged support-domain metadata, exact role IDs,
signature failures and unchanged caller-owned role maps on rejection. Its
changed-role-ID negative control must fail at the selected assertion.

The preserved public operations include candidate creation, owner-checked byte
writes and reads, dimensions, abandonment, typed String reads, checked
publication, ordinary arrays and Memory.Collect. Restricted roles are limited
to collector lifecycle/borrowed-workspace authority, raw monitor entry/release
without a typed root, and raw text commit. Native foreign-call obligations are
unchanged. Neither gate treats arbitrary native code as a sandbox.
