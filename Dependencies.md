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
- The accepted initial versions, target, provenance, hashes, and offline rules
  are frozen in `project-docs/toolchain.md` and
  `project-docs/toolchain.lock.json`.
- An unavoidable new third-party dependency requires the project owner's
  explicit approval. Vendor the exact reviewed source or binary, record its
  version, license, provenance, and integrity hash, and provide a controlled
  diagnostic when it is unavailable or corrupt.
