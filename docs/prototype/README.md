# UBE help design preview

Open [index.html](index.html) directly from disk. No server is needed.

The owner-approved prototype preserves the MSDN-style Contents layout, uses the
old manual's dark palette and purple accents, and has exactly two frames.
The left pane is a searchable disclosure tree. The shell has no header.
Each word has one HTML page with Overview, Details and Example section links.
See also explains words used in an example, or related topics when no example
is present. Bare Print is not a working native UBE statement; output needs an
object, and no guessed console API is included here.

The Ticket example displays copyable code without module headers or names,
and expected results. Main returns the price as its exit code. Reference entries
omit build/run instructions; they focus on the example and its behavior.

## Verification — 2026-11-27

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File docs/prototype/assets/tools/check-layout.ps1
rtk proxy powershell -NoProfile -File docs/prototype/assets/tools/check-example.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild bd4240e3-5cdd-434a-81d9-a09803a0aedf\generation-2\UBE.exe"
~~~

The layout gate passed local links/assets/fragments, one main per page, two
shell frames without a header, and single-page reference sections.

The example gate compares displayed code to the native fixture body and adds
the separate fixture header before compiling at O0/O2. Ages 12, 16 and 30 returned 10, 20 and 20: all six native runs
passed, with empty stdout/stderr.
Evidence: %TEMP%/ube help example e2e13dee-32ca-416d-8b86-67bbd57efa5e.
Compiler SHA256: D76D6A6489F51C3043915469F1641CFD26190BF042950A126DE3F40505DF8357.

These are scoped prototype checks. The main manual catalogue validator is not
a validator for this separate preview. Visual rendering, clipboard, browser
interaction, keyboard and screen-reader checks remain unverified: Computer Use
stopped because URL-policy enforcement is unsupported for this Windows browser.

Design accepted by the owner on 2026-11-27. Next: integrate the accepted design
into the main manual and reconcile its outdated examples.
