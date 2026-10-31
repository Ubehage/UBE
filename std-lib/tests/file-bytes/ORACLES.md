# Byte-file independent acceptance oracles

Specified before execution. A passing native harness must assert:

- all 256 byte values including embedded zero survive exact loading; empty,
  4095/4096/4097 bytes, exact limit and limit+1 have independently known outcomes;
- too-large input is rejected before read-payload allocation or read calls;
- missing, malformed/zero/empty UTF-8 path, directory and invalid span fail with
  fresh status/Failure/Err and preserve prior output; valid calls preserve Err 77;
- invalid/stale tokens never reach the OS, repeated zero close succeeds,
  sequential token identities do not repeat, and no resource survives close;
- deterministic read failure preserves destination, positive partial reads remain
  progress, premature EOF and input growth fail without replacing old output;
- Unicode BMP and supplementary path/argument bytes match independent UTF-8;
- cancellation-style early return closes the stepwise reader; independent native
  workers own private readers and buffers; open/close and managed-storage balance
  return to baseline;
- allocation failure preserves outputs and every successfully opened handle is
  closed, including failure before registry publication and final snapshot;
- ordinary UBE loader bodies execute through both v2 stages, with exact native
  exit/stdout/stderr and byte-identical LLVM; untested obligations are reported.

No successful compilation alone establishes any of these properties.
