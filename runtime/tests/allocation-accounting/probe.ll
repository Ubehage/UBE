@test.ctx = global %ube.context zeroinitializer
@test.array = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}
@test.calls = global i64 0
@test.failures = global i64 0
@test.requested = global i64 0

define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %called = atomicrmw add ptr @test.calls, i64 1 monotonic
 store i64 %bytes, ptr @test.requested
 %left = load i64, ptr @test.failures
 %reject = icmp ne i64 %left, 0
 br i1 %reject, label %fail, label %allocate
fail:
 %less = sub i64 %left, 1
 store i64 %less, ptr @test.failures
 ret ptr null
allocate:
 %block = call ptr @test.target.allocate(i64 %bytes)
 ret ptr %block
}

define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.ctx)
 %initial = call i1 @ube.array.tryresize(ptr @test.ctx, ptr @test.array, i64 4, i64 0, i64 1, ptr null)
 br i1 %initial, label %prepare, label %fail
prepare:
 %data.ptr = getelementptr {i64,i64,ptr,ptr}, ptr @test.array, i32 0, i32 2
 %old.data = load ptr, ptr %data.ptr
 store i64 77, ptr %old.data
 store i64 0, ptr @test.calls
 store i64 2, ptr @test.failures
 %refused = call i1 @ube.array.tryresize(ptr @test.ctx, ptr @test.array, i64 33554432, i64 -1, i64 1, ptr null)
 %calls = load i64, ptr @test.calls
 %requested = load i64, ptr @test.requested
 %still.data = load ptr, ptr %data.ptr
 %retained = load i64, ptr %still.data
 %error = load atomic i64, ptr @test.ctx monotonic, align 8
 %no = xor i1 %refused, true
 %twice = icmp eq i64 %calls, 2
 %large = icmp ugt i64 %requested, 134217728
 %same = icmp eq ptr %old.data, %still.data
 %value.ok = icmp eq i64 %retained, 77
 %error.ok = icmp eq i64 %error, 7
 %a = and i1 %no, %twice
 %b = and i1 %large, %same
 %c = and i1 %value.ok, %error.ok
 %ab = and i1 %a, %b
 %admitted = and i1 %ab, %c
 br i1 %admitted, label %overflow, label %fail
overflow:
 store i64 0, ptr @test.calls
 %extent = call ptr @ube.memory.new(ptr @test.ctx, i64 9223372036854775807, i64 128)
 %bad.stride = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 0)
 %bytes.ptr = call ptr @ube.memory.bytes(ptr @test.ctx)
 %count.ptr = call ptr @ube.memory.count(ptr @test.ctx)
 %actual.bytes = load i64, ptr %bytes.ptr
 %actual.count = load i64, ptr %count.ptr
 store i64 9223372036854775807, ptr %bytes.ptr
 %accounting = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 store i64 %actual.bytes, ptr %bytes.ptr
 store i64 9223372036854775807, ptr %count.ptr
 %counting = call ptr @ube.memory.new(ptr @test.ctx, i64 1, i64 1)
 store i64 %actual.count, ptr %count.ptr
 %after.calls = load i64, ptr @test.calls
 %extent.no = icmp eq ptr %extent, null
 %stride.no = icmp eq ptr %bad.stride, null
 %accounting.no = icmp eq ptr %accounting, null
 %counting.no = icmp eq ptr %counting, null
 %no.calls = icmp eq i64 %after.calls, 0
 %d = and i1 %extent.no, %stride.no
 %e = and i1 %accounting.no, %counting.no
 %de = and i1 %d, %e
 %guarded = and i1 %de, %no.calls
 br i1 %guarded, label %retry, label %fail
retry:
 %retried = call i1 @ube.array.tryresize(ptr @test.ctx, ptr @test.array, i64 8, i64 -1, i64 1, ptr null)
 %new.data = load ptr, ptr %data.ptr
 %value = load i64, ptr %new.data
 %tail.ptr = getelementptr i64, ptr %new.data, i64 7
 %tail = load i64, ptr %tail.ptr
 %kept = icmp eq i64 %value, 77
 %zero = icmp eq i64 %tail, 0
 call void @ube.array.clear(ptr @test.ctx, ptr @test.array)
 %released = call i1 @ube.memory.collect(ptr @test.ctx)
 %bytes = load i64, ptr %bytes.ptr
 %count = load i64, ptr %count.ptr
 %empty.bytes = icmp eq i64 %bytes, 0
 %empty.count = icmp eq i64 %count, 0
 %f = and i1 %retried, %kept
 %g = and i1 %zero, %empty.bytes
 %fg = and i1 %f, %g
 %all = and i1 %fg, %empty.count
 %exit = select i1 %all, i32 0, i32 1
 ret i32 %exit
fail:
 ret i32 1
}
