# Task 4 verification

Run `run-task4.ps1` from PowerShell. It rebuilds Compiler v4 twice with the
preserved v3 oracle, builds the native v4 compiler, compares the complete RP2
lexical corpus plus a multi-source conditional project, checks deterministic
repetition and controlled failures, exercises malformed bytes and bounded
limits, and records a 100/1,000/5,000-statement size series in
`bootstrap/out/v4-task4/evidence.json`.
