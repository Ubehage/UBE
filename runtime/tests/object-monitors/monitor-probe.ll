@monitor.ctx = global %ube.context zeroinitializer
@monitor.frame = global %ube.rootframe zeroinitializer
@monitor.slot = global i64 0
@monitor.descriptor = constant i64 3
@monitor.offset = constant i64 0
@monitor.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @monitor.offset,i64 0,ptr null,i64 0,ptr null}
@monitor.busy = global i64 0
@monitor.acquired = global i64 0
@monitor.worker.ok = global i64 0

; These native tests use a no-op automatic callback and explicitly exercise the real snapshot gate.
; Source-level tests must additionally qualify the ordinary UBE collector and generated cleanup.
define {i1,i64} @monitor.collector(ptr %ctx, i64 %report) {
  ret {i1,i64} {i1 true,i64 0}
}
define i1 @monitor.worker(ptr %ctx, ptr %capture) {
entry:
  %identity = load atomic i64, ptr %capture acquire, align 8
  store atomic i64 888, ptr %ctx monotonic, align 8
  br label %attempt
attempt:
  %remaining = phi i64 [5000, %entry], [%next, %retry]
  %result = call {i1,i64} @ube.monitor.tryenter(ptr %ctx, i64 %identity)
  %ok = extractvalue {i1,i64} %result, 0
  %value = extractvalue {i1,i64} %result, 1
  br i1 %ok, label %inspect, label %failed
inspect:
  %held = icmp ne i64 %value, 0
  br i1 %held, label %acquired, label %busy
busy:
  store atomic i64 1, ptr @monitor.busy release, align 8
  %expired = icmp eq i64 %remaining, 0
  br i1 %expired, label %failed, label %retry
retry:
  %yielded = call i1 @ube.monitor.yield(ptr %ctx)
  %next = sub i64 %remaining, 1
  br label %attempt
acquired:
  store atomic i64 1, ptr @monitor.acquired release, align 8
  %fields = call ptr @ube.object.address(ptr %ctx, i64 %identity, ptr @monitor.descriptor)
  %present = icmp ne ptr %fields, null
  br i1 %present, label %read, label %release.failure
read:
  %observed = load i64, ptr %fields, align 8
  %visible = icmp eq i64 %observed, 77
  %left = call i1 @ube.monitor.leave(ptr %ctx, i64 %identity)
  %error = load atomic i64, ptr %ctx monotonic, align 8
  %sticky = icmp eq i64 %error, 888
  %a = and i1 %visible, %left
  %good = and i1 %a, %sticky
  %answer = zext i1 %good to i64
  store atomic i64 %answer, ptr @monitor.worker.ok release, align 8
  ret i1 %good
release.failure:
  %released = call i1 @ube.monitor.leave(ptr %ctx, i64 %identity)
  br label %failed
failed:
  ret i1 false
}
define i32 @main() {
entry:
  %candidate = alloca i64, align 8
  %work = alloca i64, align 8
  %error = alloca i64, align 8
  %allocations = alloca i64, align 8
  %roots = alloca i64, align 8
  %root.identity = alloca i64, align 8
  %retire.identity = alloca i64, align 8
  %retire.acquired = alloca i64, align 8
  call void @ube.context.init(ptr @monitor.ctx)
  %current = call {i1,i64} @ube.thread.current(ptr @monitor.ctx)
  %registered = extractvalue {i1,i64} %current, 0
  %installed = call i1 @ube.managed.install(ptr @monitor.ctx, ptr @monitor.collector)
  %ready = and i1 %registered, %installed
  br i1 %ready, label %nothing, label %failed
nothing:
  store atomic i64 73, ptr @monitor.ctx monotonic, align 8
  %empty.nominal = call {i1,i64} @ube.object.nominal(ptr @monitor.ctx, i64 0)
  %empty.success = extractvalue {i1,i64} %empty.nominal, 0
  %empty.value = extractvalue {i1,i64} %empty.nominal, 1
  %empty.zero = icmp eq i64 %empty.value, 0
  %empty.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %empty.sticky = icmp eq i64 %empty.error, 73
  %empty.a = and i1 %empty.success, %empty.zero
  %empty.ok = and i1 %empty.a, %empty.sticky
  br i1 %empty.ok, label %null.acquire, label %failed
null.acquire:
  %null.result = call {i1,i64} @ube.monitor.tryenter(ptr @monitor.ctx, i64 0)
  %null.success = extractvalue {i1,i64} %null.result, 0
  %null.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %controlled = icmp eq i64 %null.error, 91
  %null.failed = xor i1 %null.success, true
  %null.ok = and i1 %controlled, %null.failed
  br i1 %null.ok, label %retire.failed, label %failed
retire.failed:
  store i64 0, ptr %retire.identity, align 8
  store i64 1, ptr %retire.acquired, align 8
  %invalid.retire = call i1 @ube.monitor.retire(ptr @monitor.ctx, ptr %retire.identity, ptr %retire.acquired)
  %invalid.failed = xor i1 %invalid.retire, true
  %retained.flag = load i64, ptr %retire.acquired, align 8
  %retained.identity = load i64, ptr %retire.identity, align 8
  %retained.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %flag.intact = icmp eq i64 %retained.flag, 1
  %identity.intact = icmp eq i64 %retained.identity, 0
  %failure.error = icmp eq i64 %retained.error, 91
  %failure.state = and i1 %flag.intact, %identity.intact
  %failure.result = and i1 %invalid.failed, %failure.error
  %failure.correct = and i1 %failure.state, %failure.result
  br i1 %failure.correct, label %wrong.kind, label %failed
wrong.kind:
  call void @ube.managed.root.push(ptr @monitor.ctx, ptr @monitor.frame, ptr @monitor.slot, ptr @monitor.layout, i64 1)
  %wrong.created = call i1 @ube.text.create(ptr @monitor.ctx, i64 1, i64 1, ptr %candidate)
  br i1 %wrong.created, label %wrong.nominal, label %failed
wrong.nominal:
  %wrong.identity = load i64, ptr %candidate, align 8
  %wrong.result = call {i1,i64} @ube.object.nominal(ptr @monitor.ctx, i64 %wrong.identity)
  %wrong.success = extractvalue {i1,i64} %wrong.result, 0
  %wrong.value = extractvalue {i1,i64} %wrong.result, 1
  %wrong.zero = icmp eq i64 %wrong.value, 0
  %wrong.failed = xor i1 %wrong.success, true
  %wrong.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %wrong.controlled = icmp eq i64 %wrong.error, 5
  %wrong.abandoned = call i1 @ube.text.abandon(ptr @monitor.ctx, i64 %wrong.identity)
  %wrong.a = and i1 %wrong.zero, %wrong.failed
  %wrong.b = and i1 %wrong.controlled, %wrong.abandoned
  %wrong.ok = and i1 %wrong.a, %wrong.b
  br i1 %wrong.ok, label %create, label %failed
create:
  store i64 1234, ptr %candidate, align 8
  %bad.create = call i1 @ube.object.create(ptr @monitor.ctx, ptr @monitor.descriptor, ptr null, i64 -1, ptr null, ptr %candidate)
  %unchanged.value = load i64, ptr %candidate, align 8
  %unchanged = icmp eq i64 %unchanged.value, 1234
  %rejected = xor i1 %bad.create, true
  %bad.ok = and i1 %unchanged, %rejected
  br i1 %bad.ok, label %allocate, label %failed
allocate:
  %created = call i1 @ube.object.create(ptr @monitor.ctx, ptr @monitor.descriptor, ptr null, i64 8, ptr null, ptr %candidate)
  br i1 %created, label %publish, label %failed
publish:
  %identity = load i64, ptr %candidate, align 8
  call void @ube.managed.store(ptr @monitor.ctx, ptr @monitor.slot, i64 %identity)
  %record = call ptr @ube.managed.candidate(ptr @monitor.ctx, i64 %identity)
  call void @ube.managed.unlink(ptr @monitor.ctx, ptr %record)
  store atomic i64 777, ptr @monitor.ctx monotonic, align 8
  %nominal.result = call {i1,i64} @ube.object.nominal(ptr @monitor.ctx, i64 %identity)
  %nominal.success = extractvalue {i1,i64} %nominal.result, 0
  %nominal.value = extractvalue {i1,i64} %nominal.result, 1
  %nominal.exact = icmp eq i64 %nominal.value, 3
  %nominal.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %nominal.sticky = icmp eq i64 %nominal.error, 777
  %nominal.a = and i1 %nominal.success, %nominal.exact
  %nominal.ok = and i1 %nominal.a, %nominal.sticky
  br i1 %nominal.ok, label %acquire, label %failed
acquire:
  %first = call {i1,i64} @ube.monitor.tryenter(ptr @monitor.ctx, i64 %identity)
  %second = call {i1,i64} @ube.monitor.tryenter(ptr @monitor.ctx, i64 %identity)
  %first.value = extractvalue {i1,i64} %first, 1
  %second.value = extractvalue {i1,i64} %second, 1
  %first.ok = icmp eq i64 %first.value, 1
  %second.ok = icmp eq i64 %second.value, 1
  %both = and i1 %first.ok, %second.ok
  br i1 %both, label %unacquired.retire, label %failed
unacquired.retire:
  store i64 %identity, ptr %retire.identity, align 8
  store i64 0, ptr %retire.acquired, align 8
  %unacquired.retired = call i1 @ube.monitor.retire(ptr @monitor.ctx, ptr %retire.identity, ptr %retire.acquired)
  %cleared.identity = load i64, ptr %retire.identity, align 8
  %identity.cleared = icmp eq i64 %cleared.identity, 0
  %unacquired.error = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %unacquired.sticky = icmp eq i64 %unacquired.error, 777
  %clear.ok = and i1 %unacquired.retired, %identity.cleared
  %unacquired.ok = and i1 %clear.ok, %unacquired.sticky
  br i1 %unacquired.ok, label %start, label %failed
start:
  %capsule = call ptr @ube.memory.new(ptr @monitor.ctx, i64 1, i64 1)
  %capsule.ok = icmp ne ptr %capsule, null
  br i1 %capsule.ok, label %capture, label %failed
capture:
  call void @ube.managed.owner.layout(ptr @monitor.ctx, ptr %capsule, ptr @monitor.layout, i64 1)
  %payload = getelementptr %ube.block, ptr %capsule, i64 1
  call void @ube.managed.store(ptr @monitor.ctx, ptr %payload, i64 %identity)
  %started = call {i1,i64} @ube.thread.start(ptr @monitor.ctx, ptr @monitor.worker, ptr %capsule)
  %start.ok = extractvalue {i1,i64} %started, 0
  %thread = extractvalue {i1,i64} %started, 1
  br i1 %start.ok, label %wait.busy, label %failed
wait.busy:
  %remaining = phi i64 [5000, %capture], [%next, %yield]
  %busy = load atomic i64, ptr @monitor.busy acquire, align 8
  %waiting = icmp eq i64 %busy, 1
  br i1 %waiting, label %snapshot, label %check.timeout
check.timeout:
  %expired = icmp eq i64 %remaining, 0
  br i1 %expired, label %failed, label %yield
yield:
  %yielded = call i1 @ube.monitor.yield(ptr @monitor.ctx)
  %next = sub i64 %remaining, 1
  br label %wait.busy
snapshot:
  %owned = call i1 @ube.managed.begin(ptr @monitor.ctx, ptr %work, ptr %error)
  br i1 %owned, label %counts, label %failed
counts:
  %count.ok = call i1 @ube.managed.snapshot.counts(ptr @monitor.ctx, ptr %allocations, ptr %roots)
  %root.count = load i64, ptr %roots, align 8
  br i1 %count.ok, label %scan.roots, label %end.failed
scan.roots:
  %index = phi i64 [0, %counts], [%next.index, %read.root]
  %matches = phi i64 [0, %counts], [%next.matches, %read.root]
  %read.ok = phi i1 [true, %counts], [%next.ok, %read.root]
  %more = icmp ult i64 %index, %root.count
  br i1 %more, label %read.root, label %end.snapshot
read.root:
  store i64 0, ptr %root.identity, align 8
  %found = call i1 @ube.managed.root.at(ptr @monitor.ctx, i64 %index, ptr %root.identity)
  %root.value = load i64, ptr %root.identity, align 8
  %same = icmp eq i64 %root.value, %identity
  %increment = zext i1 %same to i64
  %next.matches = add i64 %matches, %increment
  %next.index = add i64 %index, 1
  %next.ok = and i1 %read.ok, %found
  br label %scan.roots
end.failed:
  %failed.end = call i1 @ube.managed.end(ptr @monitor.ctx, i64 0, i64 0)
  br label %failed
end.snapshot:
  %rooted = icmp uge i64 %matches, 2
  %ended = call i1 @ube.managed.end(ptr @monitor.ctx, i64 0, i64 0)
  %a = and i1 %read.ok, %rooted
  %snapshot.ok = and i1 %a, %ended
  br i1 %snapshot.ok, label %inner.release, label %failed
inner.release:
  %inner = call i1 @ube.monitor.leave(ptr @monitor.ctx, i64 %identity)
  %still.blocked = call {i1,i64} @ube.thread.wait(ptr @monitor.ctx, i64 %thread, i64 0)
  %wait.value = extractvalue {i1,i64} %still.blocked, 1
  %blocked = icmp eq i64 %wait.value, 0
  %acquired = load atomic i64, ptr @monitor.acquired acquire, align 8
  %not.acquired = icmp eq i64 %acquired, 0
  %b = and i1 %inner, %blocked
  %retained = and i1 %b, %not.acquired
  br i1 %retained, label %outer.release, label %failed
outer.release:
  %fields = call ptr @ube.object.address(ptr @monitor.ctx, i64 %identity, ptr @monitor.descriptor)
  store i64 77, ptr %fields, align 8
  store i64 1, ptr %retire.acquired, align 8
  %outer = call i1 @ube.monitor.retire(ptr @monitor.ctx, ptr @monitor.slot, ptr %retire.acquired)
  %released.flag = load i64, ptr %retire.acquired, align 8
  %released.identity = load atomic i64, ptr @monitor.slot acquire, align 8
  %flag.cleared = icmp eq i64 %released.flag, 0
  %target.cleared = icmp eq i64 %released.identity, 0
  %slots.cleared = and i1 %flag.cleared, %target.cleared
  %outer.correct = and i1 %outer, %slots.cleared
  %sticky.value = load atomic i64, ptr @monitor.ctx monotonic, align 8
  %sticky = icmp eq i64 %sticky.value, 777
  %waited = call {i1,i64} @ube.thread.wait(ptr @monitor.ctx, i64 %thread, i64 5000)
  %wait.ok = extractvalue {i1,i64} %waited, 0
  %finished.value = extractvalue {i1,i64} %waited, 1
  %finished = icmp eq i64 %finished.value, 1
  %worker.value = load atomic i64, ptr @monitor.worker.ok acquire, align 8
  %worker.ok = icmp eq i64 %worker.value, 1
  %c = and i1 %outer.correct, %sticky
  %d = and i1 %wait.ok, %finished
  %e = and i1 %c, %d
  %ok = and i1 %e, %worker.ok
  br i1 %ok, label %done, label %failed
done:
  ret i32 42
failed:
  ret i32 1
}
