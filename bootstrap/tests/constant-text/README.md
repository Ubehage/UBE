# Constant text arena

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/constant-text/check.ps1 -CompilerExe <UBE.exe>`.

The gate compiles the actual `ConstantText` UBE module at O0/O2. It checks exact
case-preserving UTF-8 bytes, doubled quotes, empty text, embedded zero, BOM and a
supplementary scalar; malformed encodings/quotes/spans preserve earlier output.
Repeated arena growth, concatenation and binary ordering have explicit assertions.
A changed expected byte must fail at both optimization levels.

Passed 19 literal cases plus span/growth/concatenation/order checks, with both
negative controls: `ube constant text 2f9597fd-f504-4f4f-bfaa-f1b079a855cb`.
This is compiler constant storage qualification, not managed String execution.
