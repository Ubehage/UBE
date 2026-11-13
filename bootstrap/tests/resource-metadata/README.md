# Resource metadata and namespace failure gates

Run check.ps1 and fault-check.ps1 with -BootstrapExe pointing to the current bootstrap. The source gate executes O0/O2 assertions for directory ownership, same-owner final paths, hardlink identity, readable and writable file lengths, executable spelling and 64-bit monotonic milliseconds. It compares executable stdout and file bytes independently.

File.TryIdentity writes exactly 12 opaque identity bytes only after a successful query. File.TryLength rejects directories/processes and lengths outside Long. File.Close and FinalPath accept file kinds 1/2 and directory kind 3; process kind 4 requires its own close operation. The 64-slot resource registry and context layout are unchanged. Failed closes retain ownership. Writable opens request FILE_READ_ATTRIBUTES alongside GENERIC_WRITE.

The failure gate executes 44 injected cases at both optimization levels: identity and length queries, output capacity and aliases, foreign kinds, executable spelling/conversion/allocation, full-width ticks, namespace OS failures and retry. Every case checks result, preserved outputs, exact status/Err, native call counts, successful recovery, disposal and zero live blocks. Allocation refusals exercise both allocator attempts.

Evidence: source gate f0be9542-2ec5-4a91-91da-50a7e369657c; 88 failure/recovery cases 36b58ce0-3279-4d52-b5f7-41792460d57b under the system temporary directory.
