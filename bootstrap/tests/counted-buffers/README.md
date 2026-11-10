# Counted-buffer primitives and UBECore gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/counted-buffers/check.ps1`.
The runner compiles the actual portable UBECore modules with bounded fixtures,
checks binding identities, and executes the same emitted source at O0 and O2.
It retains all generated manifests, LLVM, executables and diagnostics.

The primitive Boolean status is record-only. Ordinary AppendBytes explicitly
raises failures and publishes Used only after copying succeeds. This gate
distinguishes both behaviors; it does not claim dynamic arrays, empty default
arrays, allocation, collection or a complete standard library.

On 2026-11-10 this gate passed 25 groups on the updated VB6 bootstrap.
Evidence: `ube counted buffers 4334e8d5-f25d-45a1-9f0a-ca00fa925fe5` in the
printed temporary root. The gate copies the actual UBECore source into its
contained ordered fixture project; it does not replace the library algorithm
with hand-authored LLVM.

Five independent native checks cover logical lengths of Byte and record arrays,
negative and positive lower bounds, both overlap directions, self-copy,
zero-count endpoint access, invalid counts/offsets/spans including Long extremes,
complete destination preservation and sticky Err on success. A False primitive
result must be assigned normally, execute the later eager And operand, and avoid
an enabled handler. A failing LongLong-to-Long argument conversion instead
reports language FAIL/Err 6, preserves the receiving Boolean and enters its
handler before the primitive writes anything.

The ordinary AppendBytes checks cover successful payload-relative append,
negative Used/Count, Used beyond capacity, insufficient remaining capacity and
invalid source spans. Failures preserve Used and the caller's result variable;
the source-range failure also exercises the caller's enabled handler. The
harness passes volatile input and resets context before each check. The same
emitted LLVM runs at O0 and O2; an O2 input-two negative control must identify
the changed copy and append observations (mask 5).

Binding checks observe canonical role IDs for renamed/casefolded declarations
and ordinary behavior for a same-named user function. Invalid roles, signatures,
targets, missing/duplicate/conflicting attributes, ordinary declarations with
primitive attributes, nonempty bodies and executable Intrinsic Main must fail.
An intrinsic named Main in a Library remains a valid arbitrary declaration name.
Failed validation must preserve an earlier emitted LLVM artifact.
