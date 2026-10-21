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

### Never crash (outranks every other rule)
Coders spend hours and hours coding in UBE, and a crash loses their work. A malformed file, a bad command or MCP param, a corrupt settings file, an odd keystroke or a full disk must produce an error the user or agent can act on, never a panic. Don't ship a feature by adding a panic path; fix a crash before building on top of it.

- **Non-test code never panics.**
- **Prove it.** Every crash fix comes with a small synthetic regression test that panicked before the fix.


## 3. Git and GitHub
Reference `/Github.md` for Github rules.


### 4. Dependency-minimal and portable
Reference `/Dependencies.md` for detailed definitions on dependency-minimalism and portability.


### 5. Context & Hierarchy Rules
Reference `Hierarchy.md` for detailed hierarchy rules.


Agents are authorized to create, modify, move, and delete files within this repository when reasonably necessary to complete the requested task. Preserve unrelated work, follow the project architecture and documentation, and avoid destructive or repository-wide changes unless explicitly requested.

When implementation makes new contributor guidance necessary, agents should create
or update the relevant documentation as part of the same change. Do not assume that a
document exists merely because an earlier plan mentions it; keep this orientation list
limited to current, useful entry points.