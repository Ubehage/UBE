@fault.context = global %ube.context zeroinitializer,align 8
@fault.calls = global i64 0,align 8
@fault.hits = global i64 0,align 8
@fault.live = global i64 0,align 8
@fault.position = global i64 0,align 8
@fault.start = global i64 0,align 8
@fault.reason = global i64 0,align 8
define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %old = atomicrmw add ptr @fault.calls,i64 1 seq_cst
 %call = add i64 %old,1
 %position = load atomic i64,ptr @fault.position seq_cst,align 8
 %second = add i64 %position,1
 %first.hit = icmp eq i64 %call,%position
 %second.hit = icmp eq i64 %call,%second
 %hit = or i1 %first.hit,%second.hit
 %enabled = icmp ne i64 %position,0
 %fail = and i1 %enabled,%hit
 br i1 %fail,label %failed,label %allocate
failed:
 %hits = atomicrmw add ptr @fault.hits,i64 1 seq_cst
 ret ptr null
allocate:
 %block = call ptr @ube.target.allocate.real(i64 %bytes)
 %exists = icmp ne ptr %block,null
 br i1 %exists,label %count,label %done
count:
 %live = atomicrmw add ptr @fault.live,i64 1 seq_cst
 br label %done
done:
 ret ptr %block
}
define i1 @ube.target.release(ptr %block) {
entry:
 %released = call i1 @ube.target.release.real(ptr %block)
 br i1 %released,label %count,label %done
count:
 %old = atomicrmw sub ptr @fault.live,i64 1 seq_cst
 br label %done
done:
 ret i1 %released
}
define ptr @ube.target.thread.start(ptr %procedure,ptr %capture) {
entry:
 %flag = load atomic i64,ptr @fault.start seq_cst,align 8
 %fail = icmp ne i64 %flag,0
 br i1 %fail,label %failed,label %real
failed:
 %hits = atomicrmw add ptr @fault.hits,i64 1 seq_cst
 ret ptr null
real:
 %handle = call ptr @ube.target.thread.start.real(ptr %procedure,ptr %capture)
 ret ptr %handle
}
define i64 @fault.run(i64 %position,i64 %start) {
entry:
 call void @ube.context.init(ptr @fault.context)
 %initialized = call i1 @ube.project.init(ptr @fault.context)
 store atomic i64 0,ptr @fault.calls seq_cst,align 8
 store atomic i64 0,ptr @fault.hits seq_cst,align 8
 store atomic i64 %position,ptr @fault.position seq_cst,align 8
 store atomic i64 %start,ptr @fault.start seq_cst,align 8
 %pair = call {i1,i64} @ube.proc.EXERCISE(ptr @fault.context)
 %fresh = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %error = load i64,ptr @fault.context,align 8
 %calls = load atomic i64,ptr @fault.calls seq_cst,align 8
 %hits = load atomic i64,ptr @fault.hits seq_cst,align 8
 store atomic i64 0,ptr @fault.position seq_cst,align 8
 store atomic i64 0,ptr @fault.start seq_cst,align 8
 call void @ube.thread.root.complete(ptr @fault.context,i1 %fresh)
 %drained = call i1 @ube.thread.drain(ptr @fault.context)
 %disposed = call i1 @ube.context.dispose(ptr @fault.context)
 %live = load atomic i64,ptr @fault.live seq_cst,align 8
 %empty = icmp eq i64 %live,0
 %clean = and i1 %drained,%disposed
 %safe = and i1 %clean,%empty
 %alloc.fault = icmp ne i64 %position,0
 %start.fault = icmp ne i64 %start,0
 %fault = or i1 %alloc.fault,%start.fault
 %expected.error = select i1 %start.fault,i64 57,i64 7
 %expected.hits = select i1 %start.fault,i64 1,i64 2
 %code = icmp eq i64 %error,%expected.error
 %reached = icmp eq i64 %hits,%expected.hits
 %failed = xor i1 %fresh,true
 %failure.code = and i1 %failed,%code
 %failure = and i1 %failure.code,%reached
 %zero = icmp eq i64 %value,0
 %normal = and i1 %fresh,%zero
 %correct = select i1 %fault,i1 %failure,i1 %normal
 %outcome = and i1 %correct,%safe
 %all = and i1 %outcome,%initialized
 %owner.reason = select i1 %empty,i64 3,i64 2
 %normal.value.reason = add i64 %value,10
 %normal.error.reason = add i64 %error,20
 %normal.reason = select i1 %fresh,i64 %normal.value.reason,i64 %normal.error.reason
 %wrong.reason = select i1 %fault,i64 1,i64 %normal.reason
 %reason = select i1 %correct,i64 %owner.reason,i64 %wrong.reason
 %case = add i64 %position,1
 %base = mul i64 %case,100
 %diagnostic = add i64 %base,%reason
 store i64 %diagnostic,ptr @fault.reason,align 8
 %answer = select i1 %all,i64 %calls,i64 -1
 ret i64 %answer
}
define i32 @main() {
entry:
 %baseline = call i64 @fault.run(i64 0,i64 0)
 %positive = icmp sgt i64 %baseline,0
 %bounded = icmp ult i64 %baseline,64
 %valid = and i1 %positive,%bounded
 br i1 %valid,label %loop,label %failed
loop:
 %position = phi i64 [1,%entry],[%next,%recovered]
 %fault = call i64 @fault.run(i64 %position,i64 0)
 %refused = icmp sgt i64 %fault,0
 br i1 %refused,label %recover,label %failed
recover:
 %normal = call i64 @fault.run(i64 0,i64 0)
 %same = icmp eq i64 %normal,%baseline
 br i1 %same,label %recovered,label %failed
recovered:
 %next = add i64 %position,1
 %more = icmp ule i64 %next,%baseline
 br i1 %more,label %loop,label %start
start:
 %start.fault = call i64 @fault.run(i64 0,i64 1)
 %start.ok = icmp sgt i64 %start.fault,0
 br i1 %start.ok,label %final,label %failed
final:
 %recovery = call i64 @fault.run(i64 0,i64 0)
 %again = icmp eq i64 %recovery,%baseline
 %count = trunc i64 %baseline to i32
 %exit = select i1 %again,i32 %count,i32 99
 ret i32 %exit
failed:
 %diagnostic = load i64,ptr @fault.reason,align 8
 %code = trunc i64 %diagnostic to i32
 ret i32 %code
}
