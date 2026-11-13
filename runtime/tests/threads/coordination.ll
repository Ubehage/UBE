; Native-only lifecycle observations: concurrent waiters, cancellation and nested ignored workers.
@test.ctx = global %ube.context zeroinitializer, align 8
@test.release = global i64 0, align 8
@test.target = global i64 0, align 8
@test.mode = global i64 0, align 8
@test.child = global i64 0, align 8
@test.root = global i64 0, align 8
define i1 @test.target.worker(ptr %ctx, ptr %payload) {
entry:
 br label %poll
poll:
 %flag = load atomic i64,ptr @test.release acquire,align 8
 %ready = icmp ne i64 %flag,0
 br i1 %ready,label %done,label %pause
pause:
 call void @Sleep(i32 1)
 br label %poll
done:
 store i64 0,ptr %ctx,align 8
 ret i1 false
}
define i1 @test.waiter(ptr %ctx,ptr %payload) {
entry:
 %id = load atomic i64,ptr @test.target acquire,align 8
 %mode = load atomic i64,ptr @test.mode acquire,align 8
 store i64 211,ptr %ctx,align 8
 %pair = call {i1,i64} @ube.thread.wait(ptr %ctx,i64 %id,i64 -1)
 %fresh = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %error = load i64,ptr %ctx,align 8
 %cancel = icmp eq i64 %mode,1
 %failed = xor i1 %fresh,true
 %zero.error = icmp eq i64 %error,0
 %fail.ok = and i1 %failed,%zero.error
 %zero = icmp eq i64 %value,0
 %sticky = icmp eq i64 %error,211
 %cancel.value = and i1 %zero,%sticky
 %cancel.ok = and i1 %fresh,%cancel.value
 %ok = select i1 %cancel,i1 %cancel.ok,i1 %fail.ok
 store i64 901,ptr %ctx,align 8
 ret i1 %ok
}
define i64 @test.start(ptr %ctx,ptr %procedure) {
entry:
 %capture = call ptr @ube.memory.new(ptr %ctx,i64 1,i64 1)
 %pair = call {i1,i64} @ube.thread.start(ptr %ctx,ptr %procedure,ptr %capture)
 %ok = extractvalue {i1,i64} %pair,0
 %id = extractvalue {i1,i64} %pair,1
 br i1 %ok,label %done,label %failed
failed:
 call void @ube.block.drop(ptr %ctx, ptr %capture)
 ret i64 0
done:
 ret i64 %id
}
define i1 @test.await.waiters(i64 %id,i64 %expected) {
entry:
 %record = call ptr @ube.thread.record.find(ptr @test.ctx,i64 %id)
 %address = getelementptr %ube.worker,ptr %record,i32 0,i32 9
 %program = call ptr @ube.thread.program(ptr @test.ctx)
 %start = call i64 @GetTickCount64()
 br label %poll
poll:
 call void @ube.thread.registry.lock(ptr %program)
 %count = load i64,ptr %address,align 8
 call void @ube.thread.registry.unlock(ptr %program)
 %ready = icmp eq i64 %count,%expected
 br i1 %ready,label %done,label %clock
clock:
 %now = call i64 @GetTickCount64()
 %elapsed = sub i64 %now,%start
 %late = icmp uge i64 %elapsed,5000
 br i1 %late,label %failed,label %pause
pause:
 call void @Sleep(i32 1)
 br label %poll
done:
 ret i1 true
failed:
 ret i1 false
}
define i1 @test.child.worker(ptr %ctx,ptr %payload) {
entry:
 %id = load atomic i64,ptr @test.root acquire,align 8
 %pair = call {i1,i64} @ube.thread.wait(ptr %ctx,i64 %id,i64 -1)
 %ok = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %one = icmp eq i64 %value,1
 %valid = and i1 %ok,%one
 %mark = select i1 %valid,i64 73,i64 98
 store atomic i64 %mark,ptr @test.child release,align 8
 ret i1 %valid
}
define i1 @test.parent.worker(ptr %ctx,ptr %payload) {
entry:
 %id = call i64 @test.start(ptr %ctx,ptr @test.child.worker)
 %ok = icmp sgt i64 %id,0
 ret i1 %ok
}
define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.ctx)
 %root = call {i1,i64} @ube.thread.current(ptr @test.ctx)
 %root.id = extractvalue {i1,i64} %root,1
 store atomic i64 %root.id,ptr @test.root release,align 8
 %target = call i64 @test.start(ptr @test.ctx,ptr @test.target.worker)
 store atomic i64 %target,ptr @test.target release,align 8
 %a = call i64 @test.start(ptr @test.ctx,ptr @test.waiter)
 %b = call i64 @test.start(ptr @test.ctx,ptr @test.waiter)
 %overlap = call i1 @test.await.waiters(i64 %target,i64 2)
 %dispose = call i1 @ube.thread.program.dispose(ptr @test.ctx)
 %refused = xor i1 %dispose,true
 store atomic i64 1,ptr @test.release release,align 8
 %wa = call {i1,i64} @ube.thread.wait(ptr @test.ctx,i64 %a,i64 5000)
 %wb = call {i1,i64} @ube.thread.wait(ptr @test.ctx,i64 %b,i64 5000)
 %a.ok = extractvalue {i1,i64} %wa,0
 %b.ok = extractvalue {i1,i64} %wb,0
 %a.value = extractvalue {i1,i64} %wa,1
 %b.value = extractvalue {i1,i64} %wb,1
 %a.one = icmp eq i64 %a.value,1
 %b.one = icmp eq i64 %b.value,1
 %waits.ok = and i1 %a.ok,%b.ok
 %waits.one = and i1 %a.one,%b.one
 %waits = and i1 %waits.ok,%waits.one
 store atomic i64 0,ptr @test.release release,align 8
 store atomic i64 1,ptr @test.mode release,align 8
 %next = call i64 @test.start(ptr @test.ctx,ptr @test.target.worker)
 store atomic i64 %next,ptr @test.target release,align 8
 %waiter = call i64 @test.start(ptr @test.ctx,ptr @test.waiter)
 %waiting = call i1 @test.await.waiters(i64 %next,i64 1)
 %stop = call {i1,i64} @ube.thread.request.stop(ptr @test.ctx,i64 %waiter)
 %cancelled = call {i1,i64} @ube.thread.wait(ptr @test.ctx,i64 %waiter,i64 5000)
 %cancel.ok = extractvalue {i1,i64} %cancelled,0
 %cancel.value = extractvalue {i1,i64} %cancelled,1
 %cancel.one = icmp eq i64 %cancel.value,1
 %cancel = and i1 %cancel.ok,%cancel.one
 store atomic i64 1,ptr @test.release release,align 8
 %nested = call i64 @test.start(ptr @test.ctx,ptr @test.parent.worker)
 %nested.ok = icmp sgt i64 %nested,0
 store i64 313,ptr @test.ctx,align 8
 call void @ube.thread.root.complete(ptr @test.ctx,i1 true)
 %drain = call i1 @ube.thread.drain(ptr @test.ctx)
 %error = load i64,ptr @test.ctx,align 8
 %sticky = icmp eq i64 %error,313
 %mark = load atomic i64,ptr @test.child acquire,align 8
 %child = icmp eq i64 %mark,73
 %disposed = call i1 @ube.thread.program.dispose(ptr @test.ctx)
 %collected = call i1 @ube.memory.collect(ptr @test.ctx)
 %head.ptr = call ptr @ube.memory.head(ptr @test.ctx)
 %head = load ptr,ptr %head.ptr,align 8
 %empty = icmp eq ptr %head,null
 %s0 = and i1 %overlap,%refused
 %s1 = and i1 %waits,%waiting
 %s2 = and i1 %cancel,%nested.ok
 %s3 = and i1 %drain,%sticky
 %s4 = and i1 %child,%disposed
 %s5 = and i1 %s0,%s1
 %s6 = and i1 %s2,%s3
 %s7 = and i1 %s4,%empty
 %s8 = and i1 %s5,%s6
 %all = and i1 %s8,%s7
 %exit = select i1 %all,i32 42,i32 97
 ret i32 %exit
}
