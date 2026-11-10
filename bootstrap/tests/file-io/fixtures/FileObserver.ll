; Test-only wrappers keep platform operations real while controlling bounded outcomes.
@test.read.mode = global i32 0
@test.write.mode = global i32 0
@test.flush.fail = global i1 false
@test.close.failures = global i32 0
@test.size.delta = global i64 0
@test.handles = global i64 0
@test.open.calls = global i64 0
@test.read.calls = global i64 0
@test.write.calls = global i64 0
@test.read.bytes = global i64 0
@test.write.bytes = global i64 0

; Counts actual open attempts and retains only successfully acquired native owners.
define ptr @ube.target.file.open(ptr %path, i1 %write) {
entry:
  %calls = load i64, ptr @test.open.calls
  %call.next = add i64 %calls, 1
  store i64 %call.next, ptr @test.open.calls
  %handle = call ptr @test.real.file.open(ptr %path, i1 %write)
  %valid = icmp ne ptr %handle, inttoptr (i64 -1 to ptr)
  %delta = zext i1 %valid to i64
  %live = load i64, ptr @test.handles
  %next = add i64 %live, %delta
  store i64 %next, ptr @test.handles
  ret ptr %handle
}

; Alters only reported size to exercise ordinary premature-EOF and growth policy.
define i1 @ube.target.file.size(ptr %handle, ptr %output) {
entry:
  %ok = call i1 @test.real.file.size(ptr %handle, ptr %output)
  br i1 %ok, label %adjust, label %done
adjust:
  %size = load i64, ptr %output
  %delta = load i64, ptr @test.size.delta
  %changed = add i64 %size, %delta
  store i64 %changed, ptr %output
  br label %done
done:
  ret i1 %ok
}

; Performs real reads with controlled short progress or a failure after scratch mutation.
define i1 @ube.target.file.read(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %calls = load i64, ptr @test.read.calls
  %next = add i64 %calls, 1
  store i64 %next, ptr @test.read.calls
  %mode = load i32, ptr @test.read.mode
  %zero = icmp eq i32 %mode, 3
  br i1 %zero, label %empty, label %read
empty:
  store i32 0, ptr %progress
  ret i1 true
read:
  %bounded = icmp ne i32 %mode, 0
  %large = icmp ugt i32 %count, 2
  %clip = and i1 %bounded, %large
  %request = select i1 %clip, i32 2, i32 %count
  %ok = call i1 @test.real.file.read(ptr %handle, ptr %bytes, i32 %request, ptr %progress)
  %confirmed = load i32, ptr %progress
  %wide = zext i32 %confirmed to i64
  %prior = load i64, ptr @test.read.bytes
  %total = add i64 %prior, %wide
  store i64 %total, ptr @test.read.bytes
  %fail = icmp eq i32 %mode, 1
  %result = select i1 %fail, i1 false, i1 %ok
  ret i1 %result
}

; Performs real partial writes and preserves their confirmed progress on injected failure.
define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %calls = load i64, ptr @test.write.calls
  %next = add i64 %calls, 1
  store i64 %next, ptr @test.write.calls
  %mode = load i32, ptr @test.write.mode
  %zero = icmp eq i32 %mode, 3
  br i1 %zero, label %empty, label %write
empty:
  store i32 0, ptr %progress
  ret i1 true
write:
  %failed = icmp eq i32 %mode, 1
  %cap = select i1 %failed, i32 2, i32 7
  %bounded = icmp ne i32 %mode, 0
  %large = icmp ugt i32 %count, %cap
  %clip = and i1 %bounded, %large
  %request = select i1 %clip, i32 %cap, i32 %count
  %ok = call i1 @test.real.file.write(ptr %handle, ptr %bytes, i32 %request, ptr %progress)
  %confirmed = load i32, ptr %progress
  %wide = zext i32 %confirmed to i64
  %prior = load i64, ptr @test.write.bytes
  %total = add i64 %prior, %wide
  store i64 %total, ptr @test.write.bytes
  %result = select i1 %failed, i1 false, i1 %ok
  ret i1 %result
}

; Injects flush failure without releasing the writable owner.
define i1 @ube.target.file.flush(ptr %handle) {
entry:
  %fail = load i1, ptr @test.flush.fail
  br i1 %fail, label %failed, label %flush
failed:
  ret i1 false
flush:
  %ok = call i1 @test.real.file.flush(ptr %handle)
  ret i1 %ok
}

; Keeps failed closes live and decrements handle counts only after native success.
define i1 @ube.target.file.close(ptr %handle) {
entry:
  %remaining = load i32, ptr @test.close.failures
  %fail = icmp ugt i32 %remaining, 0
  br i1 %fail, label %failed, label %close
failed:
  %less = sub i32 %remaining, 1
  store i32 %less, ptr @test.close.failures
  ret i1 false
close:
  %ok = call i1 @test.real.file.close(ptr %handle)
  %delta = zext i1 %ok to i64
  %live = load i64, ptr @test.handles
  %next = sub i64 %live, %delta
  store i64 %next, ptr @test.handles
  ret i1 %ok
}
