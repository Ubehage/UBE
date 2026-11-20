@test.context = global %ube.context zeroinitializer
@test.offset = constant i64 1
@test.layout = constant %ube.managed.layout {i64 2,i64 1,ptr @test.offset,i64 0,ptr null,i64 0,ptr null}
@test.source = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}
@test.copy = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}
@test.numeric = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}
@test.calls = global i64 0
@test.elements = global i64 0
@test.bad = global i1 false

; Instrument only the typed boundary; all copying/allocation remains production runtime.
define void @ube.managed.publish.range(ptr %ctx, ptr %destination, ptr %layout, i64 %count) {
entry:
 %layout.ok = icmp eq ptr %layout, @test.layout
 %address.ok = icmp ne ptr %destination, null
 %count.ok = icmp ugt i64 %count, 0
 %a = and i1 %layout.ok, %address.ok
 %ok = and i1 %a, %count.ok
 %bad = xor i1 %ok, true
 %old.bad = load i1, ptr @test.bad
 %new.bad = or i1 %bad, %old.bad
 store i1 %new.bad, ptr @test.bad
 %old = load i64, ptr @test.calls
 %next = add i64 %old, 1
 store i64 %next, ptr @test.calls
 %elements = load i64, ptr @test.elements
 %total = add i64 %elements, %count
 store i64 %total, ptr @test.elements
 call void @ube.managed.publish.range.actual(ptr %ctx, ptr %destination, ptr %layout, i64 %count)
 ret void
}

define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.context)
 %a = call i1 @ube.array.tryresize(ptr @test.context,ptr @test.source,i64 2,i64 0,i64 2,ptr @test.layout)
 br i1 %a,label %fill,label %fail
fill:
 %data.slot = getelementptr {i64,i64,ptr,ptr},ptr @test.source,i32 0,i32 2
 %data = load ptr,ptr %data.slot
 store i64 101,ptr %data
 %second = getelementptr i64,ptr %data,i64 2
 store i64 202,ptr %second
 %b = call i1 @ube.array.trycopy(ptr @test.context,ptr @test.copy,ptr @test.source,i64 2,ptr @test.layout)
 %c = call i1 @ube.array.tryresize(ptr @test.context,ptr @test.copy,i64 4,i64 -1,i64 2,ptr @test.layout)
 %d = call i1 @ube.array.tryresize(ptr @test.context,ptr @test.numeric,i64 2,i64 0,i64 2,ptr null)
 %bc = and i1 %b,%c
 %bcd = and i1 %bc,%d
 br i1 %bcd,label %check,label %fail
check:
 %copy.slot = getelementptr {i64,i64,ptr,ptr},ptr @test.copy,i32 0,i32 2
 %copy.data = load ptr,ptr %copy.slot
 %first.value = load i64,ptr %copy.data
 %second.ptr = getelementptr i64,ptr %copy.data,i64 2
 %second.value = load i64,ptr %second.ptr
 %tail.ptr = getelementptr i64,ptr %copy.data,i64 6
 %tail = load i64,ptr %tail.ptr
 %first.ok = icmp eq i64 %first.value,101
 %second.ok = icmp eq i64 %second.value,202
 %tail.ok = icmp eq i64 %tail,0
 %calls = load i64,ptr @test.calls
 %count = load i64,ptr @test.elements
 %calls.ok = icmp eq i64 %calls,3
 %count.ok = icmp eq i64 %count,8
 %bad = load i1,ptr @test.bad
 %good = xor i1 %bad,true
 %p = and i1 %first.ok,%second.ok
 %q = and i1 %tail.ok,%calls.ok
 %r = and i1 %count.ok,%good
 %s = and i1 %p,%q
 %all = and i1 %s,%r
 call void @ube.array.clear(ptr @test.context,ptr @test.source)
 call void @ube.array.clear(ptr @test.context,ptr @test.copy)
 call void @ube.array.clear(ptr @test.context,ptr @test.numeric)
 %collected = call i1 @ube.memory.collect(ptr @test.context)
 %exit = select i1 %all,i32 0,i32 1
 ret i32 %exit
fail:
 ret i32 2
}
