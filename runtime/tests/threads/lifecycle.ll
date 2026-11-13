@probe.context = global %ube.context zeroinitializer, align 8
@probe.other = global %ube.context zeroinitializer, align 8
@probe.arrived = global i64 0, align 8
@probe.release = global i64 0, align 8
@probe.stop = global [2 x i64] zeroinitializer, align 8
define i1 @probe.worker(ptr %ctx, ptr %payload) {
entry:
  %mode = load i64, ptr %payload, align 8
  %before = atomicrmw add ptr @probe.arrived, i64 1 seq_cst
  br label %wait
wait:
  %release = load atomic i64, ptr @probe.release seq_cst, align 8
  %ready = icmp ne i64 %release, 0
  br i1 %ready, label %done, label %yield
yield:
  call void @Sleep(i32 0)
  br label %wait
done:
  %stopped = call i1 @ube.thread.stop.requested(ptr %ctx)
  %stop = zext i1 %stopped to i64
  %where = getelementptr [2 x i64], ptr @probe.stop, i64 0, i64 %mode
  store atomic i64 %stop, ptr %where seq_cst, align 8
  %fails = icmp eq i64 %mode, 1
  %number = select i1 %fails, i64 42, i64 777
  store i64 %number, ptr %ctx, align 8
  %success = xor i1 %fails, true
  ret i1 %success
}
define i32 @main() {
entry:
  call void @ube.context.init(ptr @probe.context)
  call void @ube.context.init(ptr @probe.other)
  store i64 111, ptr @probe.context, align 8
  %root = call { i1, i64 } @ube.thread.current(ptr @probe.context)
  %root.ok = extractvalue { i1, i64 } %root, 0
  %root.id = extractvalue { i1, i64 } %root, 1
  %root.positive = icmp sgt i64 %root.id, 0
  %root.error = load i64, ptr @probe.context, align 8
  %root.sticky = icmp eq i64 %root.error, 111
  %root.valid = and i1 %root.ok, %root.positive
  %root.all = and i1 %root.valid, %root.sticky
  br i1 %root.all, label %self, label %bad1
self:
  %self.wait = call { i1, i64 } @ube.thread.wait(ptr @probe.context, i64 %root.id, i64 0)
  %self.ok = extractvalue { i1, i64 } %self.wait, 0
  %self.error = load i64, ptr @probe.context, align 8
  %self.code = icmp eq i64 %self.error, 5
  %self.failed = xor i1 %self.ok, true
  %self.all = and i1 %self.failed, %self.code
  br i1 %self.all, label %capture, label %bad2
capture:
  store i64 111, ptr @probe.context, align 8
  %a.block = call ptr @ube.memory.new(ptr @probe.context, i64 1, i64 1)
  %b.block = call ptr @ube.memory.new(ptr @probe.context, i64 1, i64 1)
  %a.exists = icmp ne ptr %a.block, null
  %b.exists = icmp ne ptr %b.block, null
  %both = and i1 %a.exists, %b.exists
  br i1 %both, label %start, label %bad3
start:
  %a.data = getelementptr %ube.block, ptr %a.block, i64 1
  %b.data = getelementptr %ube.block, ptr %b.block, i64 1
  store i64 1, ptr %a.data, align 8
  store i64 0, ptr %b.data, align 8
  %a = call { i1, i64 } @ube.thread.start(ptr @probe.context, ptr @probe.worker, ptr %a.block)
  %b = call { i1, i64 } @ube.thread.start(ptr @probe.context, ptr @probe.worker, ptr %b.block)
  %a.ok = extractvalue { i1, i64 } %a, 0
  %b.ok = extractvalue { i1, i64 } %b, 0
  %a.id = extractvalue { i1, i64 } %a, 1
  %b.id = extractvalue { i1, i64 } %b, 1
  %a.order = icmp sgt i64 %a.id, %root.id
  %b.order = icmp sgt i64 %b.id, %a.id
  %started = and i1 %a.ok, %b.ok
  %ordered = and i1 %a.order, %b.order
  %starts = and i1 %started, %ordered
  br i1 %starts, label %overlap.clock, label %bad4
overlap.clock:
  %started.at = call i64 @GetTickCount64()
  br label %overlap
overlap:
  %arrived = load atomic i64, ptr @probe.arrived seq_cst, align 8
  %two = icmp eq i64 %arrived, 2
  br i1 %two, label %timeout, label %deadline
deadline:
  %now = call i64 @GetTickCount64()
  %elapsed = sub i64 %now, %started.at
  %late = icmp uge i64 %elapsed, 5000
  br i1 %late, label %bad5, label %pause
pause:
  call void @Sleep(i32 1)
  br label %overlap
timeout:
  %timed = call { i1, i64 } @ube.thread.wait(ptr @probe.context, i64 %a.id, i64 0)
  %timed.ok = extractvalue { i1, i64 } %timed, 0
  %timed.value = extractvalue { i1, i64 } %timed, 1
  %timed.zero = icmp eq i64 %timed.value, 0
  %timed.error = load i64, ptr @probe.context, align 8
  %timed.sticky = icmp eq i64 %timed.error, 111
  %timed.valid = and i1 %timed.ok, %timed.zero
  %timed.all = and i1 %timed.valid, %timed.sticky
  br i1 %timed.all, label %stop, label %bad6
stop:
  %stop.result = call { i1, i64 } @ube.thread.request.stop(ptr @probe.context, i64 %a.id)
  %stop.ok = extractvalue { i1, i64 } %stop.result, 0
  %stop.value = extractvalue { i1, i64 } %stop.result, 1
  %stop.one = icmp eq i64 %stop.value, 1
  %stop.all = and i1 %stop.ok, %stop.one
  br i1 %stop.all, label %release, label %bad7
release:
  store atomic i64 1, ptr @probe.release seq_cst, align 8
  %wait.a = call { i1, i64 } @ube.thread.wait(ptr @probe.context, i64 %a.id, i64 5000)
  %wait.a.ok = extractvalue { i1, i64 } %wait.a, 0
  %wait.a.failed = xor i1 %wait.a.ok, true
  %wait.a.error = load i64, ptr @probe.context, align 8
  %wait.a.code = icmp eq i64 %wait.a.error, 42
  %wait.a.all = and i1 %wait.a.failed, %wait.a.code
  br i1 %wait.a.all, label %repeat, label %bad8
repeat:
  store i64 999, ptr @probe.context, align 8
  %again = call { i1, i64 } @ube.thread.wait(ptr @probe.context, i64 %a.id, i64 0)
  %again.ok = extractvalue { i1, i64 } %again, 0
  %again.failed = xor i1 %again.ok, true
  %again.error = load i64, ptr @probe.context, align 8
  %again.code = icmp eq i64 %again.error, 42
  %again.all = and i1 %again.failed, %again.code
  br i1 %again.all, label %normal, label %bad9
normal:
  store i64 999, ptr @probe.context, align 8
  %wait.b = call { i1, i64 } @ube.thread.wait(ptr @probe.context, i64 %b.id, i64 5000)
  %wait.b.ok = extractvalue { i1, i64 } %wait.b, 0
  %wait.b.value = extractvalue { i1, i64 } %wait.b, 1
  %wait.b.one = icmp eq i64 %wait.b.value, 1
  %wait.b.error = load i64, ptr @probe.context, align 8
  %wait.b.sticky = icmp eq i64 %wait.b.error, 999
  %wait.b.valid = and i1 %wait.b.ok, %wait.b.one
  %wait.b.all = and i1 %wait.b.valid, %wait.b.sticky
  br i1 %wait.b.all, label %isolated, label %bad10
isolated:
  %a.stop.ptr = getelementptr [2 x i64], ptr @probe.stop, i64 0, i64 1
  %a.stopped = load atomic i64, ptr %a.stop.ptr seq_cst, align 8
  %b.stopped = load atomic i64, ptr @probe.stop seq_cst, align 8
  %a.stop.one = icmp eq i64 %a.stopped, 1
  %b.stop.zero = icmp eq i64 %b.stopped, 0
  %stops = and i1 %a.stop.one, %b.stop.zero
  %foreign = call { i1, i64 } @ube.thread.wait(ptr @probe.other, i64 %a.id, i64 0)
  %foreign.ok = extractvalue { i1, i64 } %foreign, 0
  %foreign.failed = xor i1 %foreign.ok, true
  %foreign.error = load i64, ptr @probe.other, align 8
  %foreign.code = icmp eq i64 %foreign.error, 5
  %foreign.valid = and i1 %foreign.failed, %foreign.code
  %isolated.all = and i1 %stops, %foreign.valid
  br i1 %isolated.all, label %dispose, label %bad11
dispose:
  call void @ube.thread.root.complete(ptr @probe.context, i1 true)
  %drained = call i1 @ube.thread.drain(ptr @probe.context)
  %disposed = call i1 @ube.thread.program.dispose(ptr @probe.context)
  %collected = call i1 @ube.memory.collect(ptr @probe.context)
  %head.ptr = call ptr @ube.memory.head(ptr @probe.context)
  %head = load ptr, ptr %head.ptr, align 8
  %empty = icmp eq ptr %head, null
  %cleanup = and i1 %drained, %disposed
  %clean = and i1 %cleanup, %empty
  br i1 %clean, label %success, label %bad12
success:
  ret i32 42
bad1:
  ret i32 1
bad2:
  ret i32 2
bad3:
  ret i32 3
bad4:
  ret i32 4
bad5:
  ret i32 5
bad6:
  ret i32 6
bad7:
  ret i32 7
bad8:
  ret i32 8
bad9:
  ret i32 9
bad10:
  ret i32 10
bad11:
  ret i32 11
bad12:
  ret i32 12
}
