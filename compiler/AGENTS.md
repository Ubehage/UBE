# UBE Compiler Instructions for Agents

This folder contains the UBE compiler written in UBE.
This is seperate from the zero-stage C++ compiler.

## Golden rules for coding
- **Never duplicate functionality**
  If a needed function already exists in the compiler or standard library, do not write a new identical (or almost-identical) routine.
- **Multithreaded compiling is a project priority**
  All code must be thread-safe.
- **Export as much code as possible to the standard library**
  The compiler must be as minimal as practically possible.
  Native datatypes, intrinsics and generel runtime-functionality should be exported when practical and when it doesn't affect runtime performance.


## Bootstrapping and build policy

Each new compiler generation must have its own subfolder, named `UBE_Compiler_v1`, `UBE_Compiler_v2`, and so on.
Increase the version number when creating a new compiler generation, not for routine builds or tests.

Each compiler generation must follow these conventions:
- The project file must have the same name as its containing folder, e.g. UBE_Compiler_v1.UBE.
- The startup module must always be named Main.bas.
- Build outputs must be kept separate from source files.
- After a release preview passes its complete stability gate, copy its final
  executable to `compiler/release-previews/`, name it with its compiler
  generation, preview, host, and target, update `SHA256SUMS.txt`, and include
  both files in the preview's Git commit. Never overwrite an earlier stable
  preview with a later build.

Previous working compiler generations must be preserved unless explicitly authorized otherwise.

Bootstrap stages and compiler versions are not the same thing. Different bootstrap stages may compile the same UBE compiler source, and their outputs must be verifiable against each other according to the project's bootstrap architecture.

## Roadmap and progress tracking

`Roadmap.md` contains the overall development plan, milestones, dependencies, and remaining work required to complete the compiler.
`Progress.md` Contains the detailed implementation plan and current progress of the task being worked on.

Agents must:
- Keep both files accurate and consistent.
- Update progress as tasks are completed.
- Record newly discovered tasks, dependencies, and blockers.
- Document important implementation decisions.
- Ensure that another agent or a new session can resume interrupted work without having to rediscover previous decisions.
- When a task is completed, update Roadmap.md accordingly and prepare Progress.md for the next active task.
