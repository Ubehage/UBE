@test.context = global %ube.context zeroinitializer, align 8
@test.live = global i64 0, align 8
define ptr @ube.target.allocate(i64 %bytes) {
 %p = call ptr @ube.target.allocate.real(i64 %bytes)
 %exists = icmp ne ptr %p,null
 br i1 %exists,label %count,label %done
count:
 %old = atomicrmw add ptr @test.live,i64 1 seq_cst
 br label %done
done:
 ret ptr %p
}
define i1 @ube.target.release(ptr %p) {
 %ok = call i1 @ube.target.release.real(ptr %p)
 br i1 %ok,label %count,label %done
count:
 %old = atomicrmw sub ptr @test.live,i64 1 seq_cst
 br label %done
done:
 ret i1 %ok
}
define internal void @ube.array.clear(ptr %ctx,ptr %array) {
 call void @test.real.array.clear(ptr %ctx,ptr %array)
 %observed = call {i1,i64} @ube.proc.INTERLEAVE(ptr %ctx)
 ret void
}
define i32 @main() {
 call void @ube.context.init(ptr @test.context)
 %initialized = call i1 @ube.project.init(ptr @test.context)
 %pair = call {i1,i64} @ube.proc.PROBE(ptr @test.context)
 %fresh = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %expected = icmp eq i64 %value,93018
 %a = and i1 %fresh,%expected
 %source.ok = and i1 %a,%initialized
 call void @ube.thread.root.complete(ptr @test.context,i1 %fresh)
 %drained = call i1 @ube.thread.drain(ptr @test.context)
 %resources = call i1 @ube.resource.empty(ptr @test.context)
 %disposed = call i1 @ube.context.dispose(ptr @test.context)
 %b = and i1 %drained,%resources
 %cleanup.ok = and i1 %b,%disposed
 %live = load atomic i64,ptr @test.live seq_cst,align 8
 %zero = icmp eq i64 %live,0
 %code1 = select i1 %source.ok,i32 0,i32 1
 %code2 = select i1 %cleanup.ok,i32 0,i32 2
 %code4 = select i1 %zero,i32 0,i32 4
 %code12 = or i32 %code1,%code2
 %code = or i32 %code12,%code4
 ret i32 %code
}
