# Checked LongLong bootstrap arithmetic

This focused prerequisite supports the approved fresh compiler semantic checker.
The independently reproduced bootstrap gap is recorded under
`bootstrap/out/numeric-prerequisite/57f92f43e69c4e41a33003240d5ac3ee/`: both
source-built stages reject LongLong +, -, *, integer division and Mod during
emission. Native signed-minimum negation silently wraps and preserves stale Err;
the failing native observations are under
`bootstrap/out/wide-negation/c09b7437b31c4a4b946b1b9e063b6dca/`.

Extend only the existing checked integral runtime/emitter path to signed 64-bit
operands. This is bootstrap machine arithmetic, not compiler constant evaluation
or a UBECore numeric algorithm. No new intrinsic role, frontend literal policy,
fresh-compiler executable backend, executor or public API is introduced.

The private runtime helpers `ube_checked_add_i64`, `ube_checked_sub_i64`,
`ube_checked_mul_i64`, `ube_checked_div_i64`, `ube_checked_mod_i64` and
`ube_checked_neg_i64` take/return native signed 64-bit values. They allocate and
retain nothing, use only caller values and thread-local Err, and are reentrant.
Success preserves previous Err. Overflow returns neutral zero and sets Err 6;
division/remainder by zero returns zero and sets Err 11. Division truncates
toward zero; remainder has the dividend's sign. Minimum divided by -1 overflows;
minimum Mod -1 is zero without overflow, matching the established 32-bit path.
No overflowing C operation, undefined conversion or LLVM poison is permitted.

The v2 emitter routes these operations through the helpers and emits checked
negation for LongLong. Keep the existing Byte promotion and Integer/Long paths.
Do not broaden unrelated expression/operator support or constant spellings.

The native fixture passes independently chosen values from C into intact UBE
functions; this avoids depending on unsupported 64-bit literal parsing. Check
zero, both signed boundaries and adjacent faults, mixed signs, multiplication
boundaries, division/remainder signs, narrowing and stale Err. Compare actual
values and Err after each call. Deliberately corrupt an expected value and require
rejection. Check signatures before adding a native wrapper; preserve raw LLVM
and require identical output from both source-built stages. The whole bootstrap
gate must retain every earlier assertion in addition to this focused gate.

This does not qualify all UBE LongLong syntax, constant folding, full numeric
conversions or the new semantic checker. Generic parsing/checked-value algorithms
still belong in ordinary UBECore after the separate semantic probes.
