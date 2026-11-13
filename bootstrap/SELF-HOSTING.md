# Runnable compiler and reproducible self-hosting

Status: completed on 2026-11-13 under the existing "Build compiler in UBE" item
in project-docs/Development-Plan.md. compiler/Progress.md records exact commands,
source/artifact comparisons and common conformance results. Two successive
UBE self-builds passed; LLVM is byte-identical and native images differ only
in the documented four-byte PE COFF timestamp. Concurrent compilation and
full source-level debugging retain their separate acceptance gates.

## Measured dependencies

The qualified UBE frontend and NativeLowering already accept ordered retained
module pools and produce complete LLVM. The native-lowering acceptance driver
supplies paths through test-only generated LLVM calls; it is not a production
command driver. A runnable compiler must supply those inputs itself and own
staging, backend execution and publication.

The complete driver/compiler package has 44 modules. It requires 74,893 syntax
nodes, with a largest module of 7,748 nodes. Its bootstrap-generated IR measures
9,810,828 bytes and 269,156 lines. These measured requirements prompted focused
increases to 131,072 cumulative project nodes and 500,000 output lines. The
65,536 per-module node limit and 16 MiB output byte limit remain unchanged.
Other independent frame, allocation and work bounds still apply.

Source paths must stay inside their manifest tree. Project-reference support
is not admitted by the bootstrap. Therefore bootstrap/tools/self-host-sources.ps1
packages byte-identical copies into one contained project and preserves source
order. It never rewrites procedure bodies. Additional driver/library sources
are explicit inputs. The generated Compiler.UBE and sources.sha256 identify
the exact compilation inputs; a source package alone is not a compiler build.

## Implementation boundaries

- ProjectManifest parses bounded UTF-8 manifest bytes in ordinary UBE, retains
  ordered source spans and rejects unknown/unsupported settings. Filesystem
  normalization, physical containment and duplicate-file checks belong to
  project loading, not lexical parsing.
- Project loading reads each source, retains original source identity and
  calls ProjectSyntax.TryAppendModule in manifest order. Errors retain the
  manifest/source location; a partial project cannot reach emission.
- Command processing and backend policy are ordinary UBE. Counted UTF-8
  arguments and diagnostics avoid introducing managed String merely to make
  the compiler runnable. Windows command-line quoting/parsing belongs to the
  Windows library; process arguments are never passed through a shell.
- Small target primitives supply command-line bytes, standard streams, path
  queries, exclusive staging, process control and filesystem publication.
  Their exact signatures, status/ownership rules and independent gates must
  be qualified in both emitters before the driver relies on them. Names alone
  do not grant primitive authority.
- NativeLowering owns emission validation and private scratch. Its caller
  owns the output token, closing/discarding the stage and final publication.
  Runtime/template assets remain reviewed fixed target support; compiler
  procedure bodies must be generated from current source.

The existing VB6 NativeBackend supplies the preservation cases to reproduce:
resolve output through an existing physical parent, reject every input alias
(including hard links), reserve a private adjacent stage, invoke a bounded
hidden backend directly, validate the resulting native artifact, and publish
only after success. Missing tools, nonzero exit, timeout, malformed/no output,
write/flush/close failure and publication failure preserve earlier public output.
Resource owners survive failed release for explicit retry. Cleanup must retain
the primary diagnostic and may not delete a path it did not acquire.
Once atomic publication succeeds, a subsequent temporary-stage cleanup failure
is a warning about cleanup; the completed output remains a successful result.

Per-request state stays caller-owned. No process-global current project or
diagnostic is introduced. These sequential self-hosting checks do not establish
the separate concurrency gate or full source-level debugging.

## Acceptance

1. Qualify each measured library/target dependency with native O0/O2 positive,
   invalid-input and failure/recovery assertions. Check atomic outputs, exact
   status, sticky Err and balanced owners at each relevant boundary.
2. Build the real UBE command driver and compiler sources with the existing
   VB6 bootstrap. Exercise multi-module manifests, source diagnostics, missing
   inputs/assets, invalid arguments and guarded backend publication.
3. Use that executable to compile the same exact source package into a new
   compiler executable, then repeat through its output. No test-injected
   frontend entry calls or host-generated procedure bodies may substitute for
   the runnable UBE driver.
4. Compare successive UBE-generated LLVM byte-for-byte. Compare native
   artifacts under documented packaging normalization only; report differences
   rather than quietly excluding them. VB6 and UBE emitters may use different
   valid IR numbering, so their shared obligation is observable conformance.
5. Run identical positive, negative and recovery corpora through the VB6 and
   UBE compiler executables. Include checked scalar/error flow, records/arrays,
   aliases, file operations, initialization, bounds, malformed source, failed
   backend/output preservation and successful recovery. Changed inputs must
   invalidate independently expected observations.
6. Record commands, exact source/artifact identities, assertion results and
   limits in compiler/Progress.md. Only then complete the self-hosting roadmap
   item; concurrency and broader language work retain their separate gates.
