@test.context = global %ube.context zeroinitializer, align 8
@test.live = global i64 0, align 8
define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %p = call ptr @ube.target.allocate.real(i64 %bytes)
 %ok = icmp ne ptr %p,null
 br i1 %ok,label %count,label %done
count:
 %old = atomicrmw add ptr @test.live,i64 1 seq_cst
 br label %done
done:
 ret ptr %p
}
define i1 @ube.target.release(ptr %p) {
entry:
 %ok = call i1 @ube.target.release.real(ptr %p)
 br i1 %ok,label %count,label %done
count:
 %old = atomicrmw sub ptr @test.live,i64 1 seq_cst
 br label %done
done:
 ret i1 %ok
}
define i1 @test.result({i1,i64} %pair) {
 %fresh = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %zero = icmp eq i64 %value,0
 %ok = and i1 %fresh,%zero
 ret i1 %ok
}
define i32 @main() {
entry:
 %token = alloca i64,align 8
 %failure = alloca i64,align 8
 %schedule.value = alloca i64,align 8
 br label %loop
loop:
 %schedule = phi i64 [0,%entry],[%next,%advance]
 call void @ube.context.init(ptr @test.context)
 %initialized = call i1 @ube.project.init(ptr @test.context)
 store i64 %schedule,ptr %schedule.value,align 8
 %exercise = call {i1,i64} @ube.proc.PROBE(ptr @test.context,i64 0,ptr %schedule.value)
 %correct = call i1 @test.result({i1,i64} %exercise)
 %empty = call i1 @ube.resource.empty(ptr @test.context)
 %a = and i1 %initialized,%correct
 %b = and i1 %a,%empty
 br i1 %b,label %open,label %failed
open:
 store i64 0,ptr %token,align 8
 store i64 0,ptr %failure,align 8
 %opened = call {i1,i64} @ube.proc.PROBE(ptr @test.context,i64 1,ptr %token)
 %open.ok = call i1 @test.result({i1,i64} %opened)
 %owned = load i64,ptr %token,align 8
 %slot = call ptr @ube.resource.acquire(ptr @test.context,i64 %owned,ptr %failure)
 %claimed = icmp ne ptr %slot,null
 %open.valid = and i1 %open.ok,%claimed
 br i1 %open.valid,label %busy,label %failed
busy:
 %contended = call {i1,i64} @ube.proc.PROBE(ptr @test.context,i64 2,ptr %token)
 call void @ube.resource.unlock(ptr %slot)
 %busy.ok = call i1 @test.result({i1,i64} %contended)
 %live.owner = call i1 @ube.resource.empty(ptr @test.context)
 %still.owned = xor i1 %live.owner,true
 call void @ube.thread.root.complete(ptr @test.context,i1 true)
 %drained = call i1 @ube.thread.drain(ptr @test.context)
 %early.dispose = call i1 @ube.context.dispose(ptr @test.context)
 %refused = xor i1 %early.dispose,true
 %closed = call {i1,i64} @ube.proc.PROBE(ptr @test.context,i64 3,ptr %token)
 %close.ok = call i1 @test.result({i1,i64} %closed)
 %no.owners = call i1 @ube.resource.empty(ptr @test.context)
 %disposed = call i1 @ube.context.dispose(ptr @test.context)
 %live = load atomic i64,ptr @test.live seq_cst,align 8
 %zero.live = icmp eq i64 %live,0
 %c = and i1 %busy.ok,%still.owned
 %d = and i1 %close.ok,%no.owners
 %e = and i1 %drained,%disposed
 %f = and i1 %c,%d
 %g = and i1 %e,%zero.live
 %fg = and i1 %f,%g
 %all = and i1 %fg,%refused
 br i1 %all,label %advance,label %failed
advance:
 %next = add i64 %schedule,1
 %more = icmp ult i64 %next,4
 br i1 %more,label %loop,label %done
done:
 ret i32 0
failed:
 %code = add i64 %schedule,101
 %exit = trunc i64 %code to i32
 ret i32 %exit
}
