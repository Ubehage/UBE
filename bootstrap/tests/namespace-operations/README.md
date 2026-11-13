# Namespace operations gate

Run check.ps1 -BootstrapExe <current bootstrap>. The source gate executes 44 assertions at O0/O2 for Path.TryKind, exclusive Directory.TryCreate, empty-only Directory.TryRemove, File.TryDelete and File.TryReplace. Replacement uses MoveFileExW flags 9 (replace existing and write through), without cross-volume copy. Inputs use the shared strict UTF-8 path decoder and 4096-byte bound. No primitive recursively removes directories or decides compiler publication policy.

Create collisions (native 80/183) report Failure 17 / Err 58. Mutation missing paths (native 2/3) report Failure 18 / Err 53; other native refusals report Failure 5 / Err 57. Path.TryKind succeeds with Kind 0 only for native errors 2/3, Kind 1 for a file and Kind 2 for a directory. Unexpected errors preserve Kind and fail. Request and allocation failures retain established codes 1/3 and Err 5/7.

The source gate checks exact replaced bytes, missing-source preservation, wrong-kind refusals and cleanup. Evidence: 04e4aad6-d24d-4b83-98c8-8f07168b7fef. The resource-metadata fault gate additionally covers injected collisions, access refusal, missing paths, cross-volume replacement, aliases, allocation failure, recovery and leak checks.
