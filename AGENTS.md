# AGENTS.md: guide for AI agents and contributors

UBE is an open-source, native, compiler for a new language derived from classic Visual Basic 6, written exclusively in UBE (C++ with gcc is used for bootstrapping).
Its source syntax is intended to accept classic VB6 source while giving new features well-defined, modern semantics.
**No Tauri, Electron or webview shells**
The product name is always written **UBE** (acronym for Ube's Basic Experiment)
The goal is a compiler that produces lightweight, optimized, and lightning-fast code, rivaling the performance of VB6, and fully 64bit.
The compiler must also support debugging, as an IDE mimicking VB6's ease of use will also be made at a later stage.



## 1. Orientation

| Read | Why |
|---|---|
| `Release-Requirements.md` | Owner-defined requirements for the next release |
| `Workplan.md` | Current repository-wide goals, progress, and resumable handoff |
| `Owner-ideas.md` | List of ideas to consider during project development |
| `Agent-ideas.md` | List of ideas from the agents to the owner |
| `lang-doc/language-spec.md` | Normative lexical and semantic rules |
| `lang-doc/grammar/ube.ebnf` | Normative core grammar |
| `project-docs/architecture.md` | Bootstrap, compiler, runtime, and standard-library boundaries |
| `lang-doc/bootstrap-profile.md` | Implemented stage-zero subset and requirements for the UBE-written compiler |
| `bootstrap/README.md` (when present) | Building and testing the stage-zero compiler |
| `project-docs/Roadmap.md` | Tracks the work from stage zero through a self-hosting compiler, runtime, standard library, debugger, and native IDE |
| `source-library/` | Separate UBE source library, its boundary, and resumable roadmap |
| `CONTRIBUTORS.md` | List of everyone who worked on this project. They must be credited in the final program |
| `docs/` | Public offline UBE language manual |
| `lang-doc/` | Normative and internal language-definition documents |
| `project-docs/` | Architecture and project-wide planning documents |
| `GitHub.md` | Agent instructions for using GitHub |
| `media/` | Contains cliparts, pictures, icons, and other resources to use in the project |


## 2. Golden rules

### Never crash (outranks every other rule)
Coders spend hours and hours coding in UBE, and a crash loses their work. A malformed file, a bad command or MCP param, a corrupt settings file, an odd keystroke or a full disk must produce an error the user or agent can act on, never a panic. Don't ship a feature by adding a panic path; fix a crash before building on top of it.

- **Non-test code never panics.**
- **Prove it.** Every crash fix comes with a small synthetic regression test that panicked before the fix.


## Git and GitHub
The project uses Git and GitHub for version control.
Before performing Git or GitHub operations, read and follow `/GitHub.md`.
These instructions are mandatory for all agents, regardless of their assigned role or task.


### Dependency-minimal and portable

UBE and its supporting tools must be as dependency-free and portable as
practical. npm and npm-managed tooling are forbidden throughout the repository.
Do not introduce Node.js build steps, JavaScript package managers, downloaded
web frameworks, runtime CDNs, or install-on-first-run behavior.

- Prefer UBE code, operating-system facilities, and small repository-owned
  implementations over third-party libraries.
- Check in every source file, script, asset, data table, and runtime component
  required for a supported checkout to work. Builds and documentation must not
  fetch executable code or content from the network.
- Browser-facing work may use standards-based HTML, CSS, and JavaScript that is
  stored directly in the repository and works without a package manager.
- Treat the current GCC, LLVM/Clang, MinGW-w64, and PowerShell bootstrap tools
  as explicit temporary prerequisites, not permission to add hidden
  dependencies. Pin and document them, and move releases toward a portable,
  self-contained toolchain bundle as self-hosting matures.
- An unavoidable new third-party dependency requires the project owner's
  explicit approval. Vendor the exact reviewed source or binary, record its
  version, license, provenance, and integrity hash, and provide a controlled
  diagnostic when it is unavailable or corrupt.



### Context & Hierarchy Rules
- Each module folder should use `AGENTS.md` for local boundaries and agent
  instructions. `README.md` is always reader-facing; put internal technical
  design in `DESIGN.md` and resumable work state in the relevant roadmap or
  progress file.
- **The Nearest-Win Rule:** When operating inside a module, the nearest
  `AGENTS.md` outranks parent instructions if safe contradictions occur.


Agents are authorized to create, modify, move, and delete files within this repository when reasonably necessary to complete the requested task. Preserve unrelated work, follow the project architecture and documentation, and avoid destructive or repository-wide changes unless explicitly requested.

When implementation makes new contributor guidance necessary, agents should create
or update the relevant documentation as part of the same change. Do not assume that a
document exists merely because an earlier plan mentions it; keep this orientation list
limited to current, useful entry points.
