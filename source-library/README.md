# UBE source library

This directory is reserved for the standard source library compiled and linked
with UBE programs. It is separate from `compiler/`: compiler generations use
the library, but do not own its source.

The library will contain ordinary UBE implementations of strings,
conversions, collections, files, dates, mathematics, threading helpers, and
other reusable facilities. Small compiler intrinsics may support operations
that cannot be expressed portably in ordinary UBE, but the public operations
remain declared library APIs rather than parser keywords.

UBE has no separately installed runtime or virtual machine. A build links the
library modules and minimal program support it needs into its native output.

## Current status

The directory boundary and development rules are established. Implementation
will be a checked-in UBE project whose code is divided into meaningfully named
functional modules. Public modules and their package identity are not yet
frozen, so this directory does not currently claim an implemented API.

See [DESIGN.md](DESIGN.md) for boundaries and [ROADMAP.md](ROADMAP.md) for the
resumable implementation plan.
