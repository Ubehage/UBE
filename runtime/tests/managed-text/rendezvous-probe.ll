@rendezvous.ctx = global %ube.context zeroinitializer
@rendezvous.frame = global %ube.rootframe zeroinitializer
@rendezvous.slot = global i64 0
@rendezvous.candidate = global i64 0
@rendezvous.offset = constant i64 0
@rendezvous.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @rendezvous.offset,i64 0,ptr null,i64 0,ptr null}
@rendezvous.enabled = global i64 0
@rendezvous.arrivals = global i64 0
@rendezvous.joined = global i64 0
@rendezvous.worker.ok = global i64 0
define i1 @ube.managed.begin(ptr %ctx, ptr %work, ptr %error) {
entry:
 %enabled = load atomic i64, ptr @rendezvous.enabled seq_cst, align 8
 %gate = icmp ne i64 %enabled, 0
 br i1 %gate, label %arrive, label %begin
arrive:
 %prior = atomicrmw add ptr @rendezvous.arrivals, i64 1 seq_cst
 br label %wait
wait:
 %arrivals = load atomic i64, ptr @rendezvous.arrivals seq_cst, align 8
 %ready = icmp eq i64 %arrivals, 2
 br i1 %ready, label %begin, label %pause
pause:
 call void @Sleep(i32 0)
 br label %wait
begin:
 %result = call i1 @rendezvous.managed.begin(ptr %ctx, ptr %work, ptr %error)
 ret i1 %result
}
define i1 @rendezvous.worker(ptr %ctx, ptr %capture) {
entry:
 store atomic i64 44, ptr %ctx monotonic, align 8
 %result = call {i1,i64} @ube.managed.collect(ptr %ctx, i64 -1)
 %work = extractvalue {i1,i64} %result, 1
 %error = load atomic i64, ptr %ctx monotonic, align 8
 %length.result = call {i1,i64} @ube.text.length(ptr %ctx, ptr %capture, i1 false)
 %length = extractvalue {i1,i64} %length.result, 1
 %worked = icmp eq i64 %work, 1
 %sticky = icmp eq i64 %error, 44
 %retained = icmp eq i64 %length, 1
 %a = and i1 %worked, %sticky
 %ok = and i1 %a, %retained
 %value = zext i1 %ok to i64
 store atomic i64 %value, ptr @rendezvous.worker.ok release, align 8
 ret i1 %ok
}
define i32 @rendezvousmain() {
entry:
 call void @ube.context.init(ptr @rendezvous.ctx)
 %initialized = call i1 @ube.project.init(ptr @rendezvous.ctx)
 br i1 %initialized, label %prepare, label %fail
prepare:
 call void @ube.managed.root.push(ptr @rendezvous.ctx, ptr @rendezvous.frame, ptr @rendezvous.slot, ptr @rendezvous.layout, i64 1)
 %created = call i1 @ube.text.create(ptr @rendezvous.ctx, i64 1, i64 1, ptr @rendezvous.candidate)
 %id = load i64, ptr @rendezvous.candidate
 %written = call i1 @ube.text.write(ptr @rendezvous.ctx, i64 %id, i64 0, i64 65)
 %published = call i1 @ube.text.publish(ptr @rendezvous.ctx, ptr @rendezvous.slot, i64 %id)
 %garbage = call i1 @ube.text.create(ptr @rendezvous.ctx, i64 1, i64 1, ptr @rendezvous.candidate)
 %garbage.id = load i64, ptr @rendezvous.candidate
 %abandoned = call i1 @ube.text.abandon(ptr @rendezvous.ctx, i64 %garbage.id)
 %capsule = call ptr @ube.memory.new(ptr @rendezvous.ctx, i64 1, i64 1)
 %allocated = icmp ne ptr %capsule, null
 %a = and i1 %created, %written
 %b = and i1 %published, %garbage
 %c = and i1 %abandoned, %allocated
 %d = and i1 %a, %b
 %ready = and i1 %c, %d
 br i1 %ready, label %start, label %fail
start:
 call void @ube.managed.owner.layout(ptr @rendezvous.ctx, ptr %capsule, ptr @rendezvous.layout, i64 1)
 %payload = getelementptr %ube.block, ptr %capsule, i64 1
 call void @ube.managed.store(ptr @rendezvous.ctx, ptr %payload, i64 %id)
 store atomic i64 1, ptr @rendezvous.enabled seq_cst, align 8
 %started = call {i1,i64} @ube.thread.start(ptr @rendezvous.ctx, ptr @rendezvous.worker, ptr %capsule)
 %start.ok = extractvalue {i1,i64} %started, 0
 %thread = extractvalue {i1,i64} %started, 1
 br i1 %start.ok, label %collect, label %fail
collect:
 call void @ube.managed.store(ptr @rendezvous.ctx, ptr @rendezvous.slot, i64 0)
 store atomic i64 33, ptr @rendezvous.ctx monotonic, align 8
 %result = call {i1,i64} @ube.managed.collect(ptr @rendezvous.ctx, i64 -1)
 store atomic i64 0, ptr @rendezvous.enabled seq_cst, align 8
 %work = extractvalue {i1,i64} %result, 1
 %error = load atomic i64, ptr @rendezvous.ctx monotonic, align 8
 %waited = call {i1,i64} @ube.thread.wait(ptr @rendezvous.ctx, i64 %thread, i64 -1)
 %wait.ok = extractvalue {i1,i64} %waited, 0
 %worker.ok = load atomic i64, ptr @rendezvous.worker.ok acquire, align 8
 %joins = load atomic i64, ptr @rendezvous.joined seq_cst, align 8
 %worked = icmp eq i64 %work, 1
 %sticky = icmp eq i64 %error, 33
 %worker.passed = icmp eq i64 %worker.ok, 1
 %joined = icmp eq i64 %joins, 1
 %e = and i1 %worked, %sticky
 %f = and i1 %worker.passed, %joined
 %g = and i1 %e, %f
 %passed = and i1 %g, %wait.ok
 br i1 %passed, label %cleanup, label %fail
cleanup:
 call void @ube.managed.root.pop(ptr @rendezvous.ctx, ptr @rendezvous.frame)
 %disposed = call i1 @ube.context.dispose(ptr @rendezvous.ctx)
 %count.ptr = call ptr @ube.memory.count(ptr @rendezvous.ctx)
 %count = load i64, ptr %count.ptr
 %empty = icmp eq i64 %count, 0
 %clean = and i1 %disposed, %empty
 br i1 %clean, label %done, label %fail
done:
 ret i32 0
fail:
 ret i32 1
}
