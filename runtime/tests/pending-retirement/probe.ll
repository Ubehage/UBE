@test.ctx = global %ube.context zeroinitializer, align 8
@test.scans = global i64 0, align 8
@test.releases = global i64 0, align 8
@test.fail = global i64 0, align 8
@test.retire = global ptr null, align 8

; Invoked while the collector owns its storage lock and has passed the live head.
; Dropping a reference never takes that lock, so this is a legal interleaving.
define i1 @ube.target.release(ptr %block) {
entry:
 %later = load ptr, ptr @test.retire
 %exists = icmp ne ptr %later, null
 br i1 %exists, label %retire, label %fault
retire:
 store ptr null, ptr @test.retire
 call void @ube.block.drop(ptr @test.ctx, ptr %later)
 br label %fault
fault:
 %failed = atomicrmw xchg ptr @test.fail, i64 0 monotonic
 %refused = icmp ne i64 %failed, 0
 br i1 %refused, label %no, label %release
no:
 ret i1 false
release:
 %ok = call i1 @ube.target.release.real(ptr %block)
 br i1 %ok, label %count, label %done
count:
 %old = atomicrmw add ptr @test.releases, i64 1 monotonic
 br label %done
done:
 ret i1 %ok
}

; Checks exact scan/release counts for each retirement and retry boundary.
define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.ctx)
 %program = call ptr @ube.thread.program(ptr @test.ctx)
 %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12
 %counts = call ptr @ube.memory.count(ptr @test.ctx)
 %bytes = call ptr @ube.memory.bytes(ptr @test.ctx)
 %idle = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan0 = load i64, ptr @test.scans
 %zero = icmp eq i64 %scan0, 0
 %idle.false = xor i1 %idle, true
 %idle.ok = and i1 %zero, %idle.false
 br i1 %idle.ok, label %allocate, label %fail1
allocate:
 %first = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 call void @ube.block.retain(ptr %first)
 call void @ube.block.drop(ptr @test.ctx, ptr %first)
 %still.live = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan1 = load i64, ptr @test.scans
 %live.zero = icmp eq i64 %scan1, 0
 %live.false = xor i1 %still.live, true
 %live.ok = and i1 %live.zero, %live.false
 br i1 %live.ok, label %last, label %fail2
last:
 call void @ube.block.drop(ptr @test.ctx, ptr %first)
 %freed = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan2 = load i64, ptr @test.scans
 %release2 = load i64, ptr @test.releases
 %count2 = load i64, ptr %counts
 %s2 = icmp eq i64 %scan2, 1
 %r2 = icmp eq i64 %release2, 1
 %c2 = icmp eq i64 %count2, 0
 %a2 = and i1 %freed, %s2
 %b2 = and i1 %r2, %c2
 %ok2 = and i1 %a2, %b2
 br i1 %ok2, label %interleave, label %fail3
interleave:
 %tail = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 %head = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 call void @ube.block.drop(ptr @test.ctx, ptr %tail)
 store ptr %head, ptr @test.retire
 %tail.freed = call i1 @ube.memory.collect(ptr @test.ctx)
 %head.freed = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan3 = load i64, ptr @test.scans
 %release3 = load i64, ptr @test.releases
 %count3 = load i64, ptr %counts
 %s3 = icmp eq i64 %scan3, 3
 %r3 = icmp eq i64 %release3, 3
 %c3 = icmp eq i64 %count3, 0
 %a3 = and i1 %tail.freed, %head.freed
 %b3 = and i1 %s3, %r3
 %d3 = and i1 %a3, %b3
 %ok3 = and i1 %d3, %c3
 br i1 %ok3, label %refuse, label %fail4
refuse:
 %retry = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 call void @ube.block.drop(ptr @test.ctx, ptr %retry)
 store i64 1, ptr @test.fail
 %refused = call i1 @ube.memory.collect(ptr @test.ctx)
 %retry.freed = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan4 = load i64, ptr @test.scans
 %release4 = load i64, ptr @test.releases
 %s4 = icmp eq i64 %scan4, 5
 %r4 = icmp eq i64 %release4, 4
 %false4 = xor i1 %refused, true
 %a4 = and i1 %false4, %retry.freed
 %b4 = and i1 %s4, %r4
 %ok4 = and i1 %a4, %b4
 br i1 %ok4, label %quota, label %fail5
quota:
 ; Synthetic charged quota isolates the allocation fallback without changing bounds.
 store i64 67108864, ptr %bytes
 %denied = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 store i64 0, ptr %bytes
 %scan5 = load i64, ptr @test.scans
 %s5 = icmp eq i64 %scan5, 6
 %denied.null = icmp eq ptr %denied, null
 %ok5 = and i1 %s5, %denied.null
 br i1 %ok5, label %reuse, label %fail6
reuse:
 store i64 1, ptr %pending
 call void @ube.context.init(ptr @test.ctx)
 %reset = load i64, ptr %pending
 %idle.again = call i1 @ube.memory.collect(ptr @test.ctx)
 %scan6 = load i64, ptr @test.scans
 %s6 = icmp eq i64 %scan6, 6
 %reset.zero = icmp eq i64 %reset, 0
 %idle.again.false = xor i1 %idle.again, true
 %a6 = and i1 %s6, %reset.zero
 %ok6 = and i1 %a6, %idle.again.false
 br i1 %ok6, label %done, label %fail7
done:
 ret i32 0
fail1:
 ret i32 1
fail2:
 ret i32 2
fail3:
 ret i32 3
fail4:
 ret i32 4
fail5:
 ret i32 5
fail6:
 ret i32 6
fail7:
 ret i32 7
}
