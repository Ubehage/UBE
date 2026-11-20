@move.ctx = global %ube.context zeroinitializer
@move.a = global [4 x i64] [i64 0,i64 -1,i64 0,i64 0]
@move.b = global [4 x i64] [i64 0,i64 -1,i64 0,i64 0]
@move.c = global [4 x i64] [i64 0,i64 -1,i64 0,i64 0]
@move.d = global [4 x i64] [i64 0,i64 -1,i64 0,i64 0]
@move.go = global i64 0
@move.done = global i64 0
define i1 @move.reader(ptr %array, i64 %expected) {
entry:
 %snapshot = call {i64,i64,ptr,ptr} @ube.array.snapshot(ptr @move.ctx, ptr %array)
 %low = extractvalue {i64,i64,ptr,ptr} %snapshot, 0
 %high = extractvalue {i64,i64,ptr,ptr} %snapshot, 1
 %data = extractvalue {i64,i64,ptr,ptr} %snapshot, 2
 %block = extractvalue {i64,i64,ptr,ptr} %snapshot, 3
 %empty = icmp eq ptr %data, null
 br i1 %empty, label %empty.check, label %value.check
empty.check:
 %zero = icmp eq i64 %low, 0
 %minus = icmp eq i64 %high, -1
 %null = icmp eq ptr %block, null
 %a = and i1 %zero, %minus
 %empty.ok = and i1 %a, %null
 br label %done
value.check:
 %value = load i64, ptr %data
 %correct = icmp eq i64 %value, %expected
 %negative = icmp eq i64 %low, -3
 %upper = icmp eq i64 %high, -3
 %owned = icmp ne ptr %block, null
 %b = and i1 %correct, %negative
 %c = and i1 %upper, %owned
 %value.ok = and i1 %b, %c
 br label %done
done:
 %ok = phi i1 [%empty.ok,%empty.check],[%value.ok,%value.check]
 call void @ube.block.drop(ptr @move.ctx, ptr %block)
 ret i1 %ok
}
define i1 @move.worker(ptr %ctx, ptr %capture) {
entry:
 %a = load ptr, ptr %capture
 %second = getelementptr i64, ptr %capture, i64 1
 %b = load ptr, ptr %second
 store atomic i64 91, ptr %ctx monotonic, align 8
 br label %gate
gate:
 %go = load atomic i64, ptr @move.go acquire, align 8
 %started = icmp ne i64 %go, 0
 br i1 %started, label %loop, label %pause
pause:
 call void @Sleep(i32 0)
 br label %gate
loop:
 %index = phi i64 [0,%gate],[%next,%again]
 %first = call i1 @ube.array.move(ptr %ctx, ptr %a, ptr %b)
 %second.move = call i1 @ube.array.move(ptr %ctx, ptr %b, ptr %a)
 %error = load atomic i64, ptr %ctx monotonic, align 8
 %sticky = icmp eq i64 %error, 91
 %moves = and i1 %first, %second.move
 %ok = and i1 %moves, %sticky
 br i1 %ok, label %again, label %failed
again:
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 10000
 br i1 %more, label %loop, label %finished
finished:
 %previous = atomicrmw add ptr @move.done, i64 1 acq_rel
 ret i1 true
failed:
 ret i1 false
}
define i32 @main() {
entry:
 call void @ube.context.init(ptr @move.ctx)
 %one = call ptr @ube.memory.new(ptr @move.ctx, i64 1, i64 1)
 %two = call ptr @ube.memory.new(ptr @move.ctx, i64 1, i64 1)
 %cap.one = call ptr @ube.memory.new(ptr @move.ctx, i64 2, i64 1)
 %cap.two = call ptr @ube.memory.new(ptr @move.ctx, i64 2, i64 1)
 %data.one = getelementptr %ube.block, ptr %one, i64 1
 %data.two = getelementptr %ube.block, ptr %two, i64 1
 store i64 101, ptr %data.one
 store i64 202, ptr %data.two
 call void @ube.array.install(ptr @move.ctx, ptr @move.b, ptr %one, i64 -3, i64 -3)
 call void @ube.array.install(ptr @move.ctx, ptr @move.d, ptr %two, i64 -3, i64 -3)
 %payload.one = getelementptr %ube.block, ptr %cap.one, i64 1
 %payload.two = getelementptr %ube.block, ptr %cap.two, i64 1
 %payload.one.second = getelementptr i64, ptr %payload.one, i64 1
 %payload.two.second = getelementptr i64, ptr %payload.two, i64 1
 store ptr @move.a, ptr %payload.one
 store ptr @move.b, ptr %payload.one.second
 store ptr @move.c, ptr %payload.two
 store ptr @move.d, ptr %payload.two.second
 %start.one = call {i1,i64} @ube.thread.start(ptr @move.ctx, ptr @move.worker, ptr %cap.one)
 %start.two = call {i1,i64} @ube.thread.start(ptr @move.ctx, ptr @move.worker, ptr %cap.two)
 %id.one = extractvalue {i1,i64} %start.one, 1
 %id.two = extractvalue {i1,i64} %start.two, 1
 %retained = call {i64,i64,ptr,ptr} @ube.array.snapshot(ptr @move.ctx, ptr @move.b)
 %retained.data = extractvalue {i64,i64,ptr,ptr} %retained, 2
 %retained.block = extractvalue {i64,i64,ptr,ptr} %retained, 3
 store atomic i64 1, ptr @move.go release, align 8
 br label %read
read:
 %index = phi i64 [0,%entry],[%next,%again]
 %a = call i1 @move.reader(ptr @move.a, i64 101)
 %b = call i1 @move.reader(ptr @move.b, i64 101)
 %c = call i1 @move.reader(ptr @move.c, i64 202)
 %d = call i1 @move.reader(ptr @move.d, i64 202)
 %ab = and i1 %a, %b
 %cd = and i1 %c, %d
 %valid = and i1 %ab, %cd
 br i1 %valid, label %again, label %fail
again:
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 10000
 br i1 %more, label %read, label %join
join:
 %wait.one = call {i1,i64} @ube.thread.wait(ptr @move.ctx, i64 %id.one, i64 -1)
 %wait.two = call {i1,i64} @ube.thread.wait(ptr @move.ctx, i64 %id.two, i64 -1)
 %done = load atomic i64, ptr @move.done acquire, align 8
 %both = icmp eq i64 %done, 2
 %final.one = call i1 @move.reader(ptr @move.b, i64 101)
 %final.two = call i1 @move.reader(ptr @move.d, i64 202)
 %final.values = and i1 %final.one, %final.two
 %alias.value = load i64, ptr %retained.data
 %alias.valid = icmp eq i64 %alias.value, 101
 %owners.complete = and i1 %both, %final.values
 %complete = and i1 %owners.complete, %alias.valid
 br i1 %complete, label %cleanup, label %fail
cleanup:
 call void @ube.block.drop(ptr @move.ctx, ptr %retained.block)
 call void @ube.array.clear(ptr @move.ctx, ptr @move.a)
 call void @ube.array.clear(ptr @move.ctx, ptr @move.b)
 call void @ube.array.clear(ptr @move.ctx, ptr @move.c)
 call void @ube.array.clear(ptr @move.ctx, ptr @move.d)
 %threads = call i1 @ube.thread.program.dispose(ptr @move.ctx)
 %retired = call i1 @ube.memory.collect(ptr @move.ctx)
 %count.ptr = call ptr @ube.memory.count(ptr @move.ctx)
 %count = load i64, ptr %count.ptr
 %empty = icmp eq i64 %count, 0
 %clean = and i1 %empty, %threads
 %exit = select i1 %clean, i32 0, i32 1
 ret i32 %exit
fail:
 store atomic i64 1, ptr @move.go release, align 8
 call void @ube.thread.root.complete(ptr @move.ctx, i1 false)
 %drained.failure = call i1 @ube.thread.drain(ptr @move.ctx)
 ret i32 1
}
