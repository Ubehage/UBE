@fault.ctx = global %ube.context zeroinitializer
@fault.startup = global %ube.context zeroinitializer
@fault.frame = global %ube.rootframe zeroinitializer
@fault.slot = global i64 0
@fault.candidate = global i64 0
@fault.offset = constant i64 0
@fault.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @fault.offset,i64 0,ptr null,i64 0,ptr null}
@fault.allocate.fail = global i64 0
@fault.allocate.calls = global i64 0
@fault.collect.calls = global i64 0
@fault.workspace.fail = global i64 0
@fault.release.fail = global i64 0
@fault.edge.fail = global i64 0

define i1 @ube.managed.edge.count(ptr %ctx, i64 %identity, ptr %count) {
entry:
 %inject = load i64, ptr @fault.edge.fail
 %fail = icmp ne i64 %inject, 0
 br i1 %fail, label %refuse, label %read
refuse:
 store i64 0, ptr @fault.edge.fail
 store atomic i64 5, ptr %ctx monotonic, align 8
 ret i1 false
read:
 %result = call i1 @fault.managed.edge.count(ptr %ctx, i64 %identity, ptr %count)
 ret i1 %result
}

define i1 @ube.target.release(ptr %block) {
entry:
 %inject = load i64, ptr @fault.release.fail
 %fail = icmp ne i64 %inject, 0
 br i1 %fail, label %refuse, label %release
refuse:
 store i64 0, ptr @fault.release.fail
 ret i1 false
release:
 %released = call i1 @fault.target.release(ptr %block)
 ret i1 %released
}

define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %called = atomicrmw add ptr @fault.allocate.calls, i64 1 seq_cst
 %left = load i64, ptr @fault.allocate.fail
 %fail = icmp ne i64 %left, 0
 br i1 %fail, label %refuse, label %allocate
refuse:
 %less = sub i64 %left, 1
 store i64 %less, ptr @fault.allocate.fail
 ret ptr null
allocate:
 %block = call ptr @fault.target.allocate(i64 %bytes)
 ret ptr %block
}
define i1 @ube.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve) {
entry:
 %inject = load i64, ptr @fault.workspace.fail
 %enabled = icmp ne i64 %inject, 0
 %positive = icmp sgt i64 %count, 0
 %fail = and i1 %enabled, %positive
 br i1 %fail, label %refuse, label %borrow
refuse:
 store i64 0, ptr @fault.workspace.fail
 store atomic i64 7, ptr %ctx monotonic, align 8
 ret i1 false
borrow:
 %result = call i1 @fault.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve)
 ret i1 %result
}
define i32 @faultmain() {
entry:
 call void @ube.context.init(ptr @fault.ctx)
 %initialized = call i1 @ube.project.init(ptr @fault.ctx)
 br i1 %initialized, label %root, label %fail
root:
 call void @ube.managed.root.push(ptr @fault.ctx, ptr @fault.frame, ptr @fault.slot, ptr @fault.layout, i64 1)
 %created = call i1 @ube.text.create(ptr @fault.ctx, i64 1, i64 1, ptr @fault.candidate)
 %identity = load i64, ptr @fault.candidate
 %written = call i1 @ube.text.write(ptr @fault.ctx, i64 %identity, i64 0, i64 65)
 %published = call i1 @ube.text.publish(ptr @fault.ctx, ptr @fault.slot, i64 %identity)
 %a = and i1 %created, %written
 %b = and i1 %a, %published
 br i1 %b, label %retry, label %fail
retry:
 store i64 0, ptr @fault.allocate.calls
 store i64 0, ptr @fault.collect.calls
 store i64 1, ptr @fault.allocate.fail
 store atomic i64 42, ptr @fault.ctx monotonic, align 8
 %depth = getelementptr %ube.thread, ptr @fault.ctx, i32 0, i32 1
 store i64 4096, ptr %depth
 %retry.ok = call i1 @ube.text.create(ptr @fault.ctx, i64 1, i64 1, ptr @fault.candidate)
 %allocations = load i64, ptr @fault.allocate.calls
 %collections = load i64, ptr @fault.collect.calls
 %error = load i64, ptr @fault.ctx
 %saved.depth = load i64, ptr %depth
 %two = icmp eq i64 %allocations, 2
 %one = icmp eq i64 %collections, 1
 %sticky = icmp eq i64 %error, 42
 %depth.ok = icmp eq i64 %saved.depth, 4096
 %c = and i1 %two, %one
 %d = and i1 %sticky, %depth.ok
 %e = and i1 %c, %d
 %f = and i1 %e, %retry.ok
 br i1 %f, label %workspace, label %fail
workspace:
 store i64 0, ptr %depth
 %candidate = load i64, ptr @fault.candidate
 %abandoned = call i1 @ube.text.abandon(ptr @fault.ctx, i64 %candidate)
 %count.ptr = call ptr @ube.memory.count(ptr @fault.ctx)
 %before = load i64, ptr %count.ptr
 store i64 1, ptr @fault.workspace.fail
 %failed.collection = call {i1,i64} @ube.managed.collect(ptr @fault.ctx, i64 -1)
 %failed.work = extractvalue {i1,i64} %failed.collection, 1
 %failure.error = load i64, ptr @fault.ctx
 %after = load i64, ptr %count.ptr
 %no.work = icmp eq i64 %failed.work, 0
 %memory.error = icmp eq i64 %failure.error, 7
 %unswept = icmp eq i64 %before, %after
 %state = call ptr @ube.managed.state(ptr @fault.ctx)
 %requested.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3
 %requested = load i64, ptr %requested.ptr
 %resumed = icmp eq i64 %requested, 0
 %g = and i1 %no.work, %memory.error
 %h = and i1 %unswept, %resumed
 %i = and i1 %g, %h
 %j = and i1 %i, %abandoned
 br i1 %j, label %mark.failure, label %fail
mark.failure:
 store i64 1, ptr @fault.edge.fail
 %mark.collection = call {i1,i64} @ube.managed.collect(ptr @fault.ctx, i64 -1)
 %mark.work = extractvalue {i1,i64} %mark.collection, 1
 %mark.error = load i64, ptr @fault.ctx
 %mark.count = load i64, ptr %count.ptr
 %live.record = call ptr @ube.managed.find(ptr %state, i64 %identity)
 %mark.ptr = getelementptr %ube.managed.record, ptr %live.record, i32 0, i32 2
 %mark.value = load i64, ptr %mark.ptr
 %mark.cleared = icmp eq i64 %mark.value, 0
 %mark.no.work = icmp eq i64 %mark.work, 0
 %mark.failed = icmp eq i64 %mark.error, 5
 %mark.unswept = icmp eq i64 %mark.count, %before
 %mark.a = and i1 %mark.cleared, %mark.no.work
 %mark.b = and i1 %mark.failed, %mark.unswept
 %mark.ok = and i1 %mark.a, %mark.b
 br i1 %mark.ok, label %release.failure, label %fail
release.failure:
 store i64 1, ptr @fault.release.fail
 %release.collection = call {i1,i64} @ube.managed.collect(ptr @fault.ctx, i64 -1)
 %release.work = extractvalue {i1,i64} %release.collection, 1
 %release.error = load i64, ptr @fault.ctx
 %release.count = load i64, ptr %count.ptr
 %release.no.work = icmp eq i64 %release.work, 0
 %release.failed = icmp eq i64 %release.error, 57
 %release.retained = icmp eq i64 %release.count, %before
 %release.a = and i1 %release.no.work, %release.failed
 %release.ok = and i1 %release.a, %release.retained
 br i1 %release.ok, label %recovery, label %fail
recovery:
 %collected = call {i1,i64} @ube.managed.collect(ptr @fault.ctx, i64 -1)
 %work = extractvalue {i1,i64} %collected, 1
 %worked = icmp eq i64 %work, 1
 %live = call {i1,i64} @ube.text.length(ptr @fault.ctx, ptr @fault.slot, i1 false)
 %length = extractvalue {i1,i64} %live, 1
 %retained = icmp eq i64 %length, 1
 %k = and i1 %worked, %retained
 br i1 %k, label %exhausted, label %fail
exhausted:
 store i64 0, ptr @fault.allocate.calls
 store i64 0, ptr @fault.collect.calls
 store i64 2, ptr @fault.allocate.fail
 store i64 77, ptr @fault.candidate
 %refused = call i1 @ube.text.create(ptr @fault.ctx, i64 1, i64 1, ptr @fault.candidate)
 %refused.correct = xor i1 %refused, true
 %unchanged = load i64, ptr @fault.candidate
 %preserved = icmp eq i64 %unchanged, 77
 %attempts = load i64, ptr @fault.allocate.calls
 %rounds = load i64, ptr @fault.collect.calls
 %attempts.ok = icmp eq i64 %attempts, 2
 %rounds.ok = icmp eq i64 %rounds, 1
 %l = and i1 %refused.correct, %preserved
 %m = and i1 %attempts.ok, %rounds.ok
 %n = and i1 %l, %m
 br i1 %n, label %cleanup, label %fail
cleanup:
 call void @ube.managed.root.pop(ptr @fault.ctx, ptr @fault.frame)
 %disposed = call i1 @ube.context.dispose(ptr @fault.ctx)
 %remaining = load i64, ptr %count.ptr
 %empty = icmp eq i64 %remaining, 0
 %clean = and i1 %disposed, %empty
 br i1 %clean, label %startup, label %fail
startup:
 call void @ube.context.init(ptr @fault.startup)
 store i64 2, ptr @fault.allocate.fail
 %started = call i1 @ube.project.init(ptr @fault.startup)
 %startup.failed = xor i1 %started, true
 %startup.count.ptr = call ptr @ube.memory.count(ptr @fault.startup)
 %startup.count = load i64, ptr %startup.count.ptr
 %startup.empty = icmp eq i64 %startup.count, 0
 %startup.error = load i64, ptr @fault.startup
 %startup.error.ok = icmp eq i64 %startup.error, 7
 %o = and i1 %startup.failed, %startup.empty
 %p = and i1 %o, %startup.error.ok
 br i1 %p, label %done, label %fail
done:
 ret i32 0
fail:
 ret i32 1
}
