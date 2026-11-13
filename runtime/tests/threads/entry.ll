; Calls the generated launcher and verifies cleanup after an ignored worker observes Main's outcome.
@entry.observed = global i64 0, align 8
define i1 @entry.worker(ptr %ctx,ptr %payload) {
entry:
 %id = load i64,ptr %payload,align 8
 %pair = call {i1,i64} @ube.thread.wait(ptr %ctx,i64 %id,i64 -1)
 %fresh = extractvalue {i1,i64} %pair,0
 %matches = icmp eq i1 %fresh,MAIN_SUCCESS
 %error = load i64,ptr %ctx,align 8
 %error.ok = icmp eq i64 %error,WORKER_ERROR
 %ok = and i1 %matches,%error.ok
 %mark = select i1 %ok,i64 73,i64 98
 store atomic i64 %mark,ptr @entry.observed release,align 8
 ret i1 %ok
}
define {i1,i64} @ube.proc.17(ptr %ctx) {
entry:
 %current = call {i1,i64} @ube.thread.current(ptr %ctx)
 %id = extractvalue {i1,i64} %current,1
 %capture = call ptr @ube.memory.new(ptr %ctx,i64 1,i64 1)
 %payload = getelementptr %ube.block,ptr %capture,i64 1
 store i64 %id,ptr %payload,align 8
 %started = call {i1,i64} @ube.thread.start(ptr %ctx,ptr @entry.worker,ptr %capture)
 %fresh = extractvalue {i1,i64} %started,0
 br i1 %fresh,label %done,label %failed
done:
 store i64 MAIN_ERROR,ptr %ctx,align 8
 ret {i1,i64} {i1 MAIN_SUCCESS,i64 23}
failed:
 call void @ube.block.drop(ptr %ctx, ptr %capture)
 ret {i1,i64} zeroinitializer
}
define i32 @main() {
entry:
 %status = call i32 @entry.generated()
 %status.ok = icmp eq i32 %status,EXPECTED_STATUS
 %mark = load atomic i64,ptr @entry.observed acquire,align 8
 %mark.ok = icmp eq i64 %mark,73
 %head.ptr = call ptr @ube.memory.head(ptr @ube.entry.context)
 %head = load ptr,ptr %head.ptr,align 8
 %empty = icmp eq ptr %head,null
 %error = load i64,ptr @ube.entry.context,align 8
 %error.ok = icmp eq i64 %error,MAIN_ERROR
 %a = and i1 %status.ok,%mark.ok
 %b = and i1 %empty,%error.ok
 %all = and i1 %a,%b
 %exit = select i1 %all,i32 42,i32 99
 ret i32 %exit
}
