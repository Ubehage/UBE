@fault.context = global %ube.context zeroinitializer, align 8
@fault.trigger = global i64 0, align 8
@fault.hits = global i64 0, align 8
define i1 @fault.worker(ptr %ctx, ptr %payload) {
entry:
  %value = load i64, ptr %payload, align 8
  %ok = icmp eq i64 %value, 123
  ret i1 %ok
}
define i32 @main() {
entry:
  call void @ube.context.init(ptr @fault.context)
  %root = call { i1, i64 } @ube.thread.current(ptr @fault.context)
  %root.ok = extractvalue { i1, i64 } %root, 0
  %capture = call ptr @ube.memory.new(ptr @fault.context, i64 1, i64 1)
  %allocated = icmp ne ptr %capture, null
  %ready = and i1 %root.ok, %allocated
  br i1 %ready, label %inject, label %bad1
inject:
  %payload = getelementptr %ube.block, ptr %capture, i64 1
  store i64 123, ptr %payload, align 8
  store atomic i64 1, ptr @fault.trigger seq_cst, align 8
  %failed = call { i1, i64 } @ube.thread.start(ptr @fault.context, ptr @fault.worker, ptr %capture)
  %incorrect.success = extractvalue { i1, i64 } %failed, 0
  %correct.failure = xor i1 %incorrect.success, true
  %failed.id = extractvalue { i1, i64 } %failed, 1
  %no.id = icmp eq i64 %failed.id, 0
  %error = load i64, ptr @fault.context, align 8
  %correct.error = icmp eq i64 %error, EXPECT_ERROR
  %hits = load atomic i64, ptr @fault.hits seq_cst, align 8
  %correct.hits = icmp eq i64 %hits, EXPECT_HITS
  %refs.ptr = getelementptr %ube.block, ptr %capture, i32 0, i32 1
  %refs = load atomic i64, ptr %refs.ptr monotonic, align 8
  %retained = icmp eq i64 %refs, 1
  %failure.valid = and i1 %correct.failure, %no.id
  %error.valid = and i1 %correct.error, %correct.hits
  %all.failure = and i1 %failure.valid, %error.valid
  %all = and i1 %all.failure, %retained
  br i1 %all, label %recover, label %bad2
recover:
  store atomic i64 0, ptr @fault.trigger seq_cst, align 8
  %recovered = call { i1, i64 } @ube.thread.start(ptr @fault.context, ptr @fault.worker, ptr %capture)
  %started = extractvalue { i1, i64 } %recovered, 0
  %id = extractvalue { i1, i64 } %recovered, 1
  br i1 %started, label %wait, label %bad3
wait:
  %joined = call { i1, i64 } @ube.thread.wait(ptr @fault.context, i64 %id, i64 5000)
  %joined.ok = extractvalue { i1, i64 } %joined, 0
  %joined.value = extractvalue { i1, i64 } %joined, 1
  %one = icmp eq i64 %joined.value, 1
  %waited = and i1 %joined.ok, %one
  br i1 %waited, label %cleanup, label %bad4
cleanup:
  call void @ube.thread.root.complete(ptr @fault.context, i1 true)
  %drained = call i1 @ube.thread.drain(ptr @fault.context)
  %disposed = call i1 @ube.thread.program.dispose(ptr @fault.context)
  %collected = call i1 @ube.memory.collect(ptr @fault.context)
  %head.ptr = call ptr @ube.memory.head(ptr @fault.context)
  %head = load ptr, ptr %head.ptr, align 8
  %empty = icmp eq ptr %head, null
  %closed = and i1 %drained, %disposed
  %clean = and i1 %closed, %empty
  br i1 %clean, label %done, label %bad5
done:
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
}
