# Frontend cancellation checks

Run with a qualified compiler executable:

```powershell
./compiler/tests/scanner-cancellation/check.ps1 -CompilerExe <UBE.exe>
./compiler/tests/scanner-cancellation/inner-check.ps1 -CompilerExe <UBE.exe>
./compiler/tests/scanner-cancellation/inner-check.ps1 -CompilerExe <UBE.exe> -NegativeControl
./compiler/tests/scanner-cancellation/conditional-check.ps1 -CompilerExe <UBE.exe>
./compiler/tests/scanner-cancellation/conditional-check.ps1 -CompilerExe <UBE.exe> -NegativeControl
./compiler/tests/scanner-cancellation/read-check.ps1 -CompilerExe <UBE.exe>
```

All gates build and run at O0 and O2, with bounded child-process deadlines and evidence under TEMP. Exit status, empty output streams, and independently specified state assertions determine success.

`check.ps1` covers entry cancellation, source location, zero published token count, healthy lexical processing, and malformed UTF-8 rejection.

`inner-check.ps1` copies the actual scanner/parser into the isolated fixture and inserts a test-only visit notification immediately before existing checkpoint calls. Each of 17 cases requests the real per-thread stop signal on the seventeenth visit to a selected loop. No production test hook or artificial cancellation result is added. Cases cover quoted text, numeric text, comments, continued-line whitespace, assembly delimiters/bodies, logical lines, range traversal, selection validation, token scanning, parser token validation, skipped lines, assignment lookahead, expressions, bodies, modules, and node creation. Cancellation must be observed within 256 further visits, report code 104/reason 0, preserve prior output and Err, and leave a healthy thread unaffected. An earlier diagnostic remains unchanged.

`read-check.ps1` links the actual FileBytes algorithm against a deterministic file adapter. The adapter requests stop after one successful 64 KiB transfer. The cancellable API must leave its destination unchanged and retain ownership; the legacy API must complete despite the sticky stop flag. A simultaneous read failure must retain its I/O failure rather than being relabeled as cancellation. Failed close must retain its owner and primary error, and a later close must release it. This checks transfer-boundary cooperation and cleanup, not interruption of a blocked operating-system read.

`conditional-check.ps1` applies the same real-stop schedule to directive-word whitespace, constant declaration spelling, selected-line traversal, name lookup, input validation, and expression evaluation. It checks code 104/reason 0, unchanged selection/value outputs, and preserved per-thread Err. The negative controls disable the copied checkpoint's stop observation: scanner/parser fails with exact exit 102; conditional traversal eventually encounters a scanner checkpoint, but fails its earlier bounded-work oracle with exact exit 103.

The pre-suffix-migration compiler D00694FF12F90ECD2B75928B93827A131F13EF3FD44F14C386F8F18E3797F43D passed these gates against the corresponding source snapshot. TEMP evidence: `ube inner cancellation f1802dfb-a252-4d9d-914d-9569045093e9`, negative control `10936efe-7f9c-49d9-a5bf-47d7495cb946`; conditional `98495142-d641-4164-8a6c-347620897e1d`, negative control `a51bf16b-445f-4fe2-a23c-98169ef8df32`; reads `ube read cancellation 0b5d1dc0-7225-448d-891f-ef25c781911c`. Later grammar/library integration changes require a fresh combined qualification.

The cancellation bound counts explicit algorithmic checkpoints. Allocator operations, primitive array copies, and blocked OS operations are not a wall-clock deadline guarantee. Conditional selection/expression compatibility is additionally checked by the existing conditional-compilation gates. Integration through binding, layout, planning, and final request publication requires the corresponding compiler acceptance gates; these scanner/read fixtures alone do not establish that coverage.

Fresh combined qualification passed all six commands above with compiler SHA256 `610D4C6DF1430CEB7504867CEE274CC4986373086F343A1F8081AD686E148E15` (`ube library suffix combined compiler revised 20261128/UBE.exe` under TEMP). Evidence directories: scanner `a72e7252-4b84-4e81-bc1f-ceb8109c04c5`; inner `f9b31172-0fda-4d80-854d-9c6d59286c29`; inner negative `1e701f99-1ff1-4428-9ac7-4058af2a328c`; conditional `df6e85ad-9295-4283-9daf-8568ba09a4be`; conditional negative `c30aae87-fd2e-4da9-9463-b4556152438e`; read `ef3db84f-c7e6-41c2-a66d-02c2cbd5a95b`. Each directory uses the corresponding `ube scanner cancellation`, `ube inner cancellation`, `ube conditional cancellation`, or `ube read cancellation` TEMP prefix.
