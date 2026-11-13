@probe.first = global %ube.context zeroinitializer, align 8
@probe.second = global %ube.context zeroinitializer, align 8
@probe.arrays = global [1024 x [4 x i64]] zeroinitializer, align 8
%probe.task = type { %ube.thread, ptr, i64, i64, i64 }
@probe.task = global %probe.task zeroinitializer, align 8

; Publishes entry, snapshots one descriptor, and checks its complete empty shape.
define i32 @probe.worker(ptr %task) {
entry:
 %array.ptr = getelementptr %probe.task, ptr %task, i32 0, i32 1
 %ready = getelementptr %probe.task, ptr %task, i32 0, i32 2
 %done = getelementptr %probe.task, ptr %task, i32 0, i32 3
 %result = getelementptr %probe.task, ptr %task, i32 0, i32 4
 %array = load ptr, ptr %array.ptr
 store atomic i64 1, ptr %ready release, align 8
 %snapshot = call {i64,i64,ptr,ptr} @ube.array.snapshot(ptr %task, ptr %array)
 %lower = extractvalue {i64,i64,ptr,ptr} %snapshot, 0
 %upper = extractvalue {i64,i64,ptr,ptr} %snapshot, 1
 %data = extractvalue {i64,i64,ptr,ptr} %snapshot, 2
 %block = extractvalue {i64,i64,ptr,ptr} %snapshot, 3
 %a = icmp eq i64 %lower, 0
 %b = icmp eq i64 %upper, -1
 %c = icmp eq ptr %data, null
 %d = icmp eq ptr %block, null
 %ab = and i1 %a, %b
 %cd = and i1 %c, %d
 %ok = and i1 %ab, %cd
 %value = zext i1 %ok to i64
 store i64 %value, ptr %result
 call void @ube.block.drop(ptr %task, ptr %block)
 store atomic i64 1, ptr %done release, align 8
 ret i32 0
}

; Holds one stripe while a real worker attempts a colliding or independent snapshot.
define i1 @probe.run(ptr %owner, ptr %worker.program, ptr %held, ptr %target, i1 %blocked) {
entry:
 call void @ube.thread.init(ptr @probe.task, ptr %worker.program, ptr null)
 %array.ptr = getelementptr %probe.task, ptr @probe.task, i32 0, i32 1
 %ready = getelementptr %probe.task, ptr @probe.task, i32 0, i32 2
 %done = getelementptr %probe.task, ptr @probe.task, i32 0, i32 3
 %result = getelementptr %probe.task, ptr @probe.task, i32 0, i32 4
 store ptr %target, ptr %array.ptr
 store i64 0, ptr %ready
 store i64 0, ptr %done
 store i64 0, ptr %result
 call void @ube.array.lock(ptr %owner, ptr %held)
 %thread = call ptr @CreateThread(ptr null, i64 0, ptr @probe.worker, ptr @probe.task, i32 0, ptr null)
 %created = icmp ne ptr %thread, null
 br i1 %created, label %wait.ready, label %failed
wait.ready:
 %attempt = phi i64 [0,%entry], [%next,%yield]
 %entered = load atomic i64, ptr %ready acquire, align 8
 %is.ready = icmp eq i64 %entered, 1
 %expired = icmp eq i64 %attempt, 10000
 %stop = or i1 %is.ready, %expired
 br i1 %stop, label %observe, label %yield
yield:
 call void @Sleep(i32 0)
 %next = add i64 %attempt, 1
 br label %wait.ready
observe:
 %delay = select i1 %blocked, i32 20, i32 5000
 %wait = call i32 @WaitForSingleObject(ptr %thread, i32 %delay)
 %expected = select i1 %blocked, i32 258, i32 0
 %observed = icmp eq i32 %wait, %expected
 call void @ube.array.unlock(ptr %owner, ptr %held)
 %joined = call i32 @WaitForSingleObject(ptr %thread, i32 5000)
 %closed = call i32 @CloseHandle(ptr %thread)
 %join.ok = icmp eq i32 %joined, 0
 %close.ok = icmp ne i32 %closed, 0
 %value = load i64, ptr %result
 %value.ok = icmp eq i64 %value, 1
 %a = and i1 %observed, %is.ready
 %b = and i1 %join.ok, %close.ok
 %c = and i1 %a, %b
 %ok = and i1 %c, %value.ok
 ret i1 %ok
failed:
 call void @ube.array.unlock(ptr %owner, ptr %held)
 ret i1 false
}

; Finds real hash collisions, proves independent stripes/programs and checks reuse zeroing.
define i32 @main() {
entry:
 call void @ube.context.init(ptr @probe.first)
 call void @ube.context.init(ptr @probe.second)
 %first = call ptr @ube.thread.program(ptr @probe.first)
 %second = call ptr @ube.thread.program(ptr @probe.second)
 %base = getelementptr [1024 x [4 x i64]], ptr @probe.arrays, i64 0, i64 0
 %base.lock = call ptr @ube.array.lock.address(ptr %first, ptr %base)
 %other.lock = call ptr @ube.array.lock.address(ptr %second, ptr %base)
 %independent = icmp ne ptr %base.lock, %other.lock
 br label %find
find:
 %index = phi i64 [0,%entry], [%next,%find]
 %collision = phi ptr [null,%entry], [%new.collision,%find]
 %distinct = phi ptr [null,%entry], [%new.distinct,%find]
 %array = getelementptr [1024 x [4 x i64]], ptr @probe.arrays, i64 0, i64 %index
 %upper = getelementptr i64, ptr %array, i64 1
 store i64 -1, ptr %upper
 %lock = call ptr @ube.array.lock.address(ptr %first, ptr %array)
 %same = icmp eq ptr %lock, %base.lock
 %not.base = icmp ne i64 %index, 0
 %same.other = and i1 %same, %not.base
 %new.collision = select i1 %same.other, ptr %array, ptr %collision
 %new.distinct = select i1 %same, ptr %distinct, ptr %array
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 1024
 br i1 %more, label %find, label %check
check:
 %found.collision = icmp ne ptr %new.collision, null
 %found.distinct = icmp ne ptr %new.distinct, null
 %both = and i1 %found.collision, %found.distinct
 %found = and i1 %both, %independent
 br i1 %found, label %parallel, label %fail1
parallel:
 %different = call i1 @probe.run(ptr %first, ptr %first, ptr %base, ptr %new.distinct, i1 false)
 br i1 %different, label %programs, label %fail2
programs:
 %isolated = call i1 @probe.run(ptr %first, ptr %second, ptr %base, ptr %base, i1 false)
 br i1 %isolated, label %collision.test, label %fail3
collision.test:
 %serialized = call i1 @probe.run(ptr %first, ptr %first, ptr %base, ptr %new.collision, i1 true)
 br i1 %serialized, label %reuse, label %fail4
reuse:
 call void @ube.array.lock(ptr %first, ptr %base)
 call void @ube.context.init(ptr @probe.first)
 %reset = load atomic i64, ptr %base.lock acquire, align 8
 %zero = icmp eq i64 %reset, 0
 %size = call i64 @ube.context.size()
 %size.ok = icmp eq i64 %size, 6848
 %ok = and i1 %zero, %size.ok
 br i1 %ok, label %done, label %fail5
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
}
