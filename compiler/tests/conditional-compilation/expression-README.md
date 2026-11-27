# Conditional expression acceptance

Run the isolated evaluator gate with an existing UBE compiler:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/conditional-compilation/expression-check.ps1 -CompilerExe <UBE.exe>
```

The driver copies the current evaluator, scanner, scalar constant operations and their ordinary library dependencies into a unique temporary directory. It builds and executes independently authored expression cases at O0 and O2. Each optimization also runs a changed-expected-value control that must fail its first assertion. Build logs, executable exit results, source copies and the case ledger remain in the printed evidence directory.

The 56 expression cases cover the conditional grammar's precedence, Boolean truth tables for Xor/Eqv/Imp, integral result types, floating values, string operations, explicit false/true/false host-symbol inputs, short-circuit value suppression with continued name and type checking, controlled arithmetic errors, invalid syntax and depth limits. Rejection assertions include diagnostic category, reason and physical position. Every case runs with both a clear error record and an existing error 42. Failed evaluation must preserve the caller's result and text arena. Additional probes check invalid API bounds, recovery after rejection, and text-conversion destination validation.

`ConditionalExpressions.TryEvaluate` receives zero-based half-open expression token bounds, original source bytes, decoded ASCII-folded symbol names and typed symbol values. String symbols refer to the supplied text arena. The evaluator uses a private arena candidate and publishes result and arena only on success. The caller supplies `IS_IN_IDE`; there is no global or environment lookup.

This gate does not establish directive selection, compiler request wiring or IDE launch behavior. Based literals remain excluded because their bit-pattern interpretation is deferred by the language specification. The admitted string-comparison profile is binary; this gate does not qualify Option Compare Text.

The gate passed all four runs on 2026-11-27 using `%TEMP%/ube compiler rebuild 68e264aa-a894-4b53-83cc-6ebf408cd931/generation-2/UBE.exe`. The current-source snapshots and terminal evidence are in `%TEMP%/ube conditional expressions 3467539e-a25e-4b59-a5c7-5ade465aacce`. This records the isolated evaluator gate only.
