# UBE Compiler Instructions for Agents

This folder contains the UBE compiler written in UBE.

## Golden rules for coding
- **Never duplicate functionality**
  If a needed function already exists in the compiler or standard library, do not write a new identical (or almost-identical) routine.
- **Multithreaded compiling is a project priority**
  All code must be thread-safe.
- **Export as much code as possible to the standard library**
  The compiler must be as minimal as practically possible.
  Native datatypes, intrinsics and generel runtime-functionality should be exported when practical and when it doesn't affect runtime performance.


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
