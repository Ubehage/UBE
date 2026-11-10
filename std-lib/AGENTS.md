# UBECore Standard Library

This folder contains the UBECore project and standard library.
The project file must be `std-lib/UBECore.UBE`.
All UBECore production source files must be under `src/`.
Shared, portable production code belongs in `src/portable/`.

Platform-specific code, including constants, declarations and functions,
must be implemented in these subfolders:

- `src/win-lib/` for Windows-specific code
- `src/lin-lib/` for Linux-specific code
- `src/mac-lib/` for macOS-specific code

Platform implementations must be selected for the compilation target, not
the machine running the compiler. Portable code must use the shared platform
interface rather than depend directly on a platform-specific implementation.

Tests and maintenance scripts may live in `tests/` and `tools/` alongside
`src/`; they are not required to live under the production source directory.

Agents may create additional folders as needed within the approved project
architecture.
