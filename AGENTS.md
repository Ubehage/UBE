# AGENTS.md: guide for AI agents and contributors

UBE is an open-source, native, compiler for a new language derived from classic Visual Basic 6, written exclusively in UBE (C++ with gcc is used for bootstrapping).
Its source syntax is intended to accept classic VB6 source while giving new features well-defined, modern semantics.
**No Tauri, Electron or webview shells**

The product name is always written **UBE** (acronym for Ube's Basic Experiment)

The goal is a compiler that produces lightweight, optimized, and lightning-fast code, rivaling the performance of VB6, and fully 64bit.

The compiler must also support debugging, as an IDE mimicking VB6's ease of use will also be made at a later stage.


## 1. Orientation
Reference `/navigation.md` for details on navigating the repository.


## 2. Golden rules
## Never crash (outranks every other rule)
Coders spend hours and hours coding in UBE, and a crash loses their work. A malformed file, a bad command, a corrupt settings file, an odd keystroke or a full disk must produce an error the user or agent can act on. Don't ship a feature by adding a panic path; fix a crash before building on top of it.
- **Non-test code never panics.**
- **Prove it.** Every crash fix comes with a small synthetic regression test that panicked before the fix.

## Follow the approved plan and final architecture.
Before changing code, identify the active roadmap or workplan item being implemented. Keep the change within that item and its stated dependencies. Do not invent new phases, stage labels, compiler generations, subsystems, or architectural boundaries unless they are already part of the documented plan or the owner explicitly approves them.
Temporary implementation steps must contribute directly to the final architecture. Do not leave milestone-specific behavior, flags, naming, duplication, or dead-end abstractions in production code. Existing documented bootstrap-stage terminology remains valid.

Production identifiers must describe their lasting domain purpose. Never name functions, procedures, types, modules, files, flags, or other implementation elements after task numbers, roadmap items, phases, temporary milestones, agent plans, or work sessions. Examples of forbidden naming include Task4*, Phase2*, and Step3*.

## Verification claims require evidence.
Do not describe work as verified merely because it compiled, launched, completed without an obvious error, or appeared correct during an informal inspection.
Claim verification only when the relevant predefined test, assertion, comparison, or acceptance gate has passed. Report the exact command or procedure used, what it checked, and its result. Visual inspection verifies only the specific properties covered by an explicit checklist. If the required verification was not performed, say that the result is unverified.


## Diagnose narrowly before changing broadly
Reproduce a problem with the smallest focused sample that isolates what actually fails before changing production architecture or shared behavior. Prefer the narrowest fix justified by that evidence.

- Do not begin with a fundamental, architectural, or system-wide change when a focused diagnostic or local correction could identify or solve the problem.
- Ask the repository owner for explicit approval before making a fundamental, architectural, or system-wide change.
**Focused fixes to the clean bootstrap seed or production compiler that are necessary to complete an approved roadmap item do not require separate architectural approval.**


## 3. Git and GitHub
Reference `Github.md` for details on using GitHub.


## 4. Dependency-minimal and portable
Reference `/Dependencies.md` for detailed definitions on dependency-minimalism and portability.


## 5. Context & Hierarchy Rules
Reference `Hierarchy.md` for detailed hierarchy rules.


## 6. Agent permissions
Reference `Agent-permissions.md` for details on agent permissions.