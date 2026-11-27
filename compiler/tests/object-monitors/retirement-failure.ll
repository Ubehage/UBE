; Synthetic failure of generated cleanup routing, after a real native release.
; Restoring the metadata slots forces the compiler to mark the failed slot and
; perform terminal root cleanup, without deliberately abandoning a valid lock.
@retirement.injected = global i64 0
@retirement.target.slot = global ptr null
@retirement.terminal = global i64 0
@retirement.retries = global i64 0

define i1 @ube.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot) {
entry:
  %injected = load i64, ptr @retirement.injected, align 8
  %armed = icmp eq i64 %injected, 0
  %acquired = load i64, ptr %acquired.slot, align 8
  %held = icmp eq i64 %acquired, 1
  %inject = and i1 %armed, %held
  br i1 %inject, label %release, label %observe
release:
  %identity = load i64, ptr %identity.slot, align 8
  %released = call i1 @retirement.actual(ptr %ctx, ptr %identity.slot, ptr %acquired.slot)
  br i1 %released, label %fail.once, label %release.failed
fail.once:
  store ptr %identity.slot, ptr @retirement.target.slot, align 8
  store i64 1, ptr @retirement.injected, align 8
  call void @ube.managed.store(ptr %ctx, ptr %identity.slot, i64 %identity)
  store i64 1, ptr %acquired.slot, align 8
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret i1 false
release.failed:
  ret i1 false
observe:
  %tracked.slot = load ptr, ptr @retirement.target.slot, align 8
  %same = icmp eq ptr %tracked.slot, %identity.slot
  br i1 %same, label %inspect, label %plain
inspect:
  %empty = icmp eq i64 %acquired, 0
  br i1 %empty, label %terminal, label %retry
terminal:
  %prior = atomicrmw add ptr @retirement.terminal, i64 1 seq_cst
  br label %plain
retry:
  %repeated = atomicrmw add ptr @retirement.retries, i64 1 seq_cst
  br label %plain
plain:
  %result = call i1 @retirement.actual(ptr %ctx, ptr %identity.slot, ptr %acquired.slot)
  ret i1 %result
}

define i32 @main() {
entry:
  %source = call i32 @retirement.source.main()
  %source.ok = icmp eq i32 %source, 0
  %injected = load i64, ptr @retirement.injected, align 8
  %terminal = load i64, ptr @retirement.terminal, align 8
  %retries = load i64, ptr @retirement.retries, align 8
  %injected.once = icmp eq i64 %injected, 1
  %terminal.once = icmp eq i64 %terminal, 1
  %no.retries = icmp eq i64 %retries, 0
  %a = and i1 %source.ok, %injected.once
  %b = and i1 %terminal.once, %no.retries
  %ok = and i1 %a, %b
  %exit = select i1 %ok, i32 0, i32 99
  ret i32 %exit
}
