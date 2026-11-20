; Test-only typed graph construction exercises the production UBE traversal.
@graph.ctx = global %ube.context zeroinitializer
@graph.frame = global %ube.rootframe zeroinitializer
@graph.slots = global [2 x i64] zeroinitializer
@graph.candidate = global i64 0
@graph.offset = constant i64 0
@graph.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @graph.offset,i64 0,ptr null,i64 0,ptr null}
define i32 @graphmain() {
entry:
 call void @ube.context.init(ptr @graph.ctx)
 %initialized = call i1 @ube.project.init(ptr @graph.ctx)
 br i1 %initialized, label %prepare, label %fail
prepare:
 call void @ube.managed.root.push(ptr @graph.ctx, ptr @graph.frame, ptr @graph.slots, ptr @graph.layout, i64 1)
 br label %allocate
allocate:
 %index = phi i64 [0,%prepare],[%next,%linked]
 %old = phi i64 [0,%prepare],[%id,%linked]
 %tail = phi ptr [null,%prepare],[%first,%linked]
 %created = call i1 @ube.text.create(ptr @graph.ctx, i64 1, i64 1, ptr @graph.candidate)
 %id = load i64, ptr @graph.candidate
 %written = call i1 @ube.text.write(ptr @graph.ctx, i64 %id, i64 0, i64 65)
 %published = call i1 @ube.text.publish(ptr @graph.ctx, ptr @graph.slots, i64 %id)
 %a = and i1 %created, %written
 %ok = and i1 %a, %published
 br i1 %ok, label %metadata, label %fail
metadata:
 %state = call ptr @ube.managed.state(ptr @graph.ctx)
 %record = call ptr @ube.managed.find(ptr %state, i64 %id)
 %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7
 %repeat.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8
 %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
 %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11
 %payload = load ptr, ptr %payload.ptr
 store ptr @graph.layout, ptr %layout.ptr
 store i64 1, ptr %repeat.ptr
 store i64 2, ptr %kind.ptr
 store i64 %old, ptr %payload
 br label %linked
linked:
 %is.first = icmp eq i64 %index, 0
 %first = select i1 %is.first, ptr %payload, ptr %tail
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 3000
 br i1 %more, label %allocate, label %cycle
cycle:
 store i64 %id, ptr %first
 %lookalike.created = call i1 @ube.text.create(ptr @graph.ctx, i64 1, i64 1, ptr @graph.candidate)
 %lookalike = load i64, ptr @graph.candidate
 %abandoned = call i1 @ube.text.abandon(ptr @graph.ctx, i64 %lookalike)
 %integer.slot = getelementptr i64, ptr @graph.slots, i64 1
 store i64 %lookalike, ptr %integer.slot
 %before.count.ptr = call ptr @ube.memory.count(ptr @graph.ctx)
 %before.count = load i64, ptr %before.count.ptr
 %collected = call {i1,i64} @ube.managed.collect(ptr @graph.ctx, i64 -1)
 %work = extractvalue {i1,i64} %collected, 1
 %after.count = load i64, ptr %before.count.ptr
 %released = sub i64 %before.count, %after.count
 %one.released = icmp eq i64 %released, 1
 %worked = icmp eq i64 %work, 1
 %lookalike.record = call ptr @ube.managed.find(ptr %state, i64 %lookalike)
 %integer.not.root = icmp eq ptr %lookalike.record, null
 %head.record = call ptr @ube.managed.find(ptr %state, i64 %id)
 %head.retained = icmp ne ptr %head.record, null
 %b = and i1 %lookalike.created, %abandoned
 %c = and i1 %one.released, %worked
 %d = and i1 %integer.not.root, %head.retained
 %e = and i1 %b, %c
 %live = and i1 %d, %e
 br i1 %live, label %release.cycle, label %fail
release.cycle:
 call void @ube.managed.store(ptr @graph.ctx, ptr @graph.slots, i64 0)
 %cycle.collected = call {i1,i64} @ube.managed.collect(ptr @graph.ctx, i64 -1)
 %cycle.work = extractvalue {i1,i64} %cycle.collected, 1
 %cycle.worked = icmp eq i64 %cycle.work, 1
 %after.cycle = load i64, ptr %before.count.ptr
 %cycle.released = sub i64 %after.count, %after.cycle
 %all.released = icmp eq i64 %cycle.released, 3000
 %cycle.ok = and i1 %cycle.worked, %all.released
 br i1 %cycle.ok, label %cleanup, label %fail
cleanup:
 call void @ube.managed.root.pop(ptr @graph.ctx, ptr @graph.frame)
 %disposed = call i1 @ube.context.dispose(ptr @graph.ctx)
 %remaining = load i64, ptr %before.count.ptr
 %empty = icmp eq i64 %remaining, 0
 %clean = and i1 %disposed, %empty
 br i1 %clean, label %done, label %fail
done:
 ret i32 0
fail:
 ret i32 1
}
