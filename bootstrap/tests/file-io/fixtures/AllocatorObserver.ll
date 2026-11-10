; Test-only target wrapper replacements observe successful blocks and inject failures.
@test.alloc.calls = global i64 0
@test.live = global i64 0
@test.fail.remaining = global i64 0
@test.fail.after = global i64 0
@test.max.live = global i64 0
@test.release.failures = global i64 0

; Injects scheduled allocation failures while counting real successful blocks.
define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %calls = load i64, ptr @test.alloc.calls
  %next = add i64 %calls, 1
  store i64 %next, ptr @test.alloc.calls
  %remaining = load i64, ptr @test.fail.remaining
  %pending = icmp ugt i64 %remaining, 0
  %after = load i64, ptr @test.fail.after
  %due = icmp uge i64 %next, %after
  %forced = and i1 %pending, %due
  br i1 %forced, label %force, label %quota
force:
  %less = sub i64 %remaining, 1
  store i64 %less, ptr @test.fail.remaining
  ret ptr null
quota:
  %live = load i64, ptr @test.live
  %limit = load i64, ptr @test.max.live
  %limited = icmp ne i64 %limit, 0
  %full = icmp uge i64 %live, %limit
  %reject = and i1 %limited, %full
  br i1 %reject, label %failed, label %allocate
failed:
  ret ptr null
allocate:
  %block = call ptr @test.real.allocate(i64 %bytes)
  %nonnull = icmp ne ptr %block, null
  %increment = zext i1 %nonnull to i64
  %newlive = add i64 %live, %increment
  store i64 %newlive, ptr @test.live
  ret ptr %block
}

; Failed releases remain visible to later disposal attempts.
define i1 @ube.target.release(ptr %block) {
entry:
  %remaining = load i64, ptr @test.release.failures
  %fail = icmp ugt i64 %remaining, 0
  br i1 %fail, label %failed, label %release
failed:
  %less = sub i64 %remaining, 1
  store i64 %less, ptr @test.release.failures
  ret i1 false
release:
  %released = call i1 @test.real.release(ptr %block)
  %live = load i64, ptr @test.live
  %decrement = zext i1 %released to i64
  %newlive = sub i64 %live, %decrement
  store i64 %newlive, ptr @test.live
  ret i1 %released
}
