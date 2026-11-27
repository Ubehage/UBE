@growth.ctx = global %ube.context zeroinitializer
@growth.frame = global %ube.rootframe zeroinitializer
@growth.slots = global [17 x i64] zeroinitializer
@growth.candidate = global i64 0
@growth.offset = constant i64 0
@growth.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @growth.offset,i64 0,ptr null,i64 0,ptr null}
@growth.calls = global i64 0
@growth.failures = global i64 0

define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %before = atomicrmw add ptr @growth.calls, i64 1 monotonic
 %remaining = load i64, ptr @growth.failures
 %enabled = icmp ne i64 %remaining, 0
 %metadata = icmp uge i64 %before, 1
 %reject = and i1 %enabled, %metadata
 br i1 %reject, label %fail, label %allocate
fail:
 %less = sub i64 %remaining, 1
 store i64 %less, ptr @growth.failures
 ret ptr null
allocate:
 %block = call ptr @growth.target.allocate(i64 %bytes)
 ret ptr %block
}

define i1 @growth.create(i64 %index) {
entry:
 %created = call i1 @ube.text.create(ptr @growth.ctx, i64 1, i64 1, ptr @growth.candidate)
 br i1 %created, label %write, label %fail
write:
 %identity = load i64, ptr @growth.candidate
 %written = call i1 @ube.text.write(ptr @growth.ctx, i64 %identity, i64 0, i64 65)
 %slot = getelementptr [17 x i64], ptr @growth.slots, i64 0, i64 %index
 %published = call i1 @ube.text.publish(ptr @growth.ctx, ptr %slot, i64 %identity)
 %ok = and i1 %written, %published
 ret i1 %ok
fail:
 ret i1 false
}

define i32 @growthmain() {
entry:
 call void @ube.context.init(ptr @growth.ctx)
 %initialized = call i1 @ube.project.init(ptr @growth.ctx)
 br i1 %initialized, label %root, label %fail
root:
 call void @ube.managed.root.push(ptr @growth.ctx, ptr @growth.frame, ptr @growth.slots, ptr @growth.layout, i64 17)
 br label %create
create:
 %index = phi i64 [0,%root], [%next,%advance]
 %created = call i1 @growth.create(i64 %index)
 br i1 %created, label %advance, label %fail
advance:
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 16
 br i1 %more, label %create, label %prepare.failure
prepare.failure:
 %state = call ptr @ube.managed.state(ptr @growth.ctx)
 %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16
 %buffer.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 15
 %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17
 %snapshot.count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8
 %old.buffer = load ptr, ptr %buffer.ptr
 %old.capacity = load i64, ptr %capacity.ptr
 %sixteen = icmp eq i64 %old.capacity, 16
 store i64 987, ptr @growth.candidate
 store i64 0, ptr @growth.calls
 store i64 2, ptr @growth.failures
 %failed.create = call i1 @ube.text.create(ptr @growth.ctx, i64 1, i64 1, ptr @growth.candidate)
 %candidate = load i64, ptr @growth.candidate
 %error = load atomic i64, ptr @growth.ctx monotonic, align 8
 %calls = load i64, ptr @growth.calls
 %buffer.after = load ptr, ptr %buffer.ptr
 %capacity.after = load i64, ptr %capacity.ptr
 %live.after = load i64, ptr %live.ptr
 %failed = xor i1 %failed.create, true
 %same.output = icmp eq i64 %candidate, 987
 %memory = icmp eq i64 %error, 7
 %three.calls = icmp eq i64 %calls, 3
 %same.buffer = icmp eq ptr %old.buffer, %buffer.after
 %same.capacity = icmp eq i64 %capacity.after, 16
 %same.live = icmp eq i64 %live.after, 16
 %a = and i1 %failed, %same.output
 %b = and i1 %memory, %three.calls
 %c = and i1 %same.buffer, %same.capacity
 %d = and i1 %same.live, %sixteen
 %ab = and i1 %a, %b
 %cd = and i1 %c, %d
 %rollback = and i1 %ab, %cd
 br i1 %rollback, label %collect.old, label %fail
collect.old:
 %old.collection = call {i1,i64} @ube.managed.collect(ptr @growth.ctx, i64 -1)
 %old.ok = extractvalue {i1,i64} %old.collection, 0
 %old.live = load i64, ptr %live.ptr
 %old.snapshot = load i64, ptr %snapshot.count.ptr
 %old.live.ok = icmp eq i64 %old.live, 16
 %old.snapshot.ok = icmp eq i64 %old.snapshot, 16
 %old.counts = and i1 %old.live.ok, %old.snapshot.ok
 %old.valid = and i1 %old.ok, %old.counts
 br i1 %old.valid, label %retry, label %fail
retry:
 %retried = call i1 @growth.create(i64 16)
 %new.capacity = load i64, ptr %capacity.ptr
 %new.live = load i64, ptr %live.ptr
 %new.buffer = load ptr, ptr %buffer.ptr
 %expanded = icmp eq i64 %new.capacity, 32
 %seventeen = icmp eq i64 %new.live, 17
 %replaced = icmp ne ptr %new.buffer, %old.buffer
 %e = and i1 %retried, %expanded
 %f = and i1 %seventeen, %replaced
 %new.valid = and i1 %e, %f
 br i1 %new.valid, label %collect.new, label %fail
collect.new:
 %new.collection = call {i1,i64} @ube.managed.collect(ptr @growth.ctx, i64 -1)
 %new.ok = extractvalue {i1,i64} %new.collection, 0
 %new.snapshot = load i64, ptr %snapshot.count.ptr
 %snapshot.ok = icmp eq i64 %new.snapshot, 17
 %validated = and i1 %new.ok, %snapshot.ok
 br i1 %validated, label %clear, label %fail
clear:
 %slot.index = phi i64 [0,%collect.new], [%slot.next,%clear]
 %slot = getelementptr [17 x i64], ptr @growth.slots, i64 0, i64 %slot.index
 call void @ube.managed.store(ptr @growth.ctx, ptr %slot, i64 0)
 %slot.next = add i64 %slot.index, 1
 %slots.more = icmp ult i64 %slot.next, 17
 br i1 %slots.more, label %clear, label %cleanup
cleanup:
 call void @ube.managed.root.pop(ptr @growth.ctx, ptr @growth.frame)
 %collected = call {i1,i64} @ube.managed.collect(ptr @growth.ctx, i64 -1)
 %collected.ok = extractvalue {i1,i64} %collected, 0
 %final.live = load i64, ptr %live.ptr
 %empty = icmp eq i64 %final.live, 0
 %disposed = call i1 @ube.context.dispose(ptr @growth.ctx)
 %blocks.ptr = call ptr @ube.memory.count(ptr @growth.ctx)
 %blocks = load i64, ptr %blocks.ptr
 %released = icmp eq i64 %blocks, 0
 %g = and i1 %collected.ok, %empty
 %h = and i1 %disposed, %released
 %all = and i1 %g, %h
 %exit = select i1 %all, i32 0, i32 1
 ret i32 %exit
fail:
 ret i32 1
}
