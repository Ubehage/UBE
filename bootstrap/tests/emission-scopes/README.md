# Emission-scope indexing regression

Run `check.ps1 -ReferenceExe <previous-bootstrap.exe>` to build the current VB6
bootstrap and compare it with the previous emitter. `-BootstrapExe <current.exe>`
reuses an existing current build. VB6 compilation requires its normal registry
access; all fixtures, outputs and process observations remain in an isolated
temporary evidence directory. Child processes are hidden and time-bounded.

The focused regression creates 400 functions with 12 scalar locals each. The
previous emitter must reject this project with the unchanged emission-work
limit and preserve an existing sentinel output. The current emitter must emit
successfully and produce identical bytes on repetition. An independent LLVM
harness resolves each source function through its bound symbol identity and
checks all 400 runtime results at O0 and O2. Changing the volatile input must
fail precisely the first unchanged result assertion.

Three smaller corpora require byte-for-byte old/new LLVM equality on exactly
the same manifest and source paths: the existing dynamic-storage and aggregate
fixtures, plus a local fixture containing separate array owners, label handlers,
default error modes and grouped ByRef temporaries. This checks that scope indexes
preserve declaration order, temporary order, failure dispatch and cleanup text;
it is not a replacement for the existing native execution gates.

The gate does not raise resource ceilings, change the ABI, or partition source
programs. It specifically qualifies replacing repeated whole-project emission
scans with indexes over each scope. Full native/aggregate/dynamic/handler gates
remain separate regression evidence.
