Attribute VB_Name = "NativeThreadRuntime"
Option Explicit
' Provides native worker identity, completion, cooperative stopping and orderly lifetime ownership.
Public Function NativeThreadIR() As String
    NativeThreadIR = NativeThreadIR & NativeThreadTargets()
    NativeThreadIR = NativeThreadIR & NativeThreadIdentity()
    NativeThreadIR = NativeThreadIR & NativeThreadExecution()
    NativeThreadIR = NativeThreadIR & NativeThreadWaitOwners()
    NativeThreadIR = NativeThreadIR & NativeThreadWaiting()
    NativeThreadIR = NativeThreadIR & NativeThreadControl()
    NativeThreadIR = NativeThreadIR & NativeThreadShutdown()
End Function

' Emits the reviewed NativeThreadTargets runtime definitions.
Private Function NativeThreadTargets() As String
    Dim Text As String
    Text = Text & "; Native thread mechanics. Generated source entry thunks own typed capture cleanup." & vbCrLf
    Text = Text & "%ube.worker = type { ptr, i64, ptr, i64, i64, i64, ptr, ptr, %ube.thread, i64, i64, i64 }" & vbCrLf
    Text = Text & "@ube.thread.next = internal global i64 1" & vbCrLf
    Text = Text & "declare dllimport ptr @CreateThread(ptr, i64, ptr, ptr, i32, ptr)" & vbCrLf
    Text = Text & "define ptr @ube.target.thread.start(ptr %procedure, ptr %argument) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %handle = call ptr @CreateThread(ptr null, i64 8388608, ptr %procedure, ptr %argument, i32 65536, ptr null)" & vbCrLf
    Text = Text & "  ret ptr %handle" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.thread.wait(ptr %handle, i32 %milliseconds) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @WaitForSingleObject(ptr %handle, i32 %milliseconds)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.thread.close(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @CloseHandle(ptr %handle)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal { i1, i64 } @ube.thread.failure(ptr %ctx, i64 %number) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  store i64 %number, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  ret { i1, i64 } zeroinitializer" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal { i1, i64 } @ube.thread.value(i64 %value) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %pair = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1" & vbCrLf
    Text = Text & "  ret { i1, i64 } %pair" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.thread.registry.lock(ptr %program) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 11" & vbCrLf
    Text = Text & "  br label %acquire" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %attempt = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic" & vbCrLf
    Text = Text & "  %ok = extractvalue { i64, i1 } %attempt, 1" & vbCrLf
    Text = Text & "  br i1 %ok, label %done, label %yield" & vbCrLf
    Text = Text & "yield:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %acquire" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.thread.registry.unlock(ptr %program) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 11" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %lock release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i64 @ube.thread.issue() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %retry" & vbCrLf
    Text = Text & "retry:" & vbCrLf
    Text = Text & "  %old = load atomic i64, ptr @ube.thread.next seq_cst, align 8" & vbCrLf
    Text = Text & "  %exhausted = icmp eq i64 %old, 0" & vbCrLf
    Text = Text & "  br i1 %exhausted, label %failed, label %issue" & vbCrLf
    Text = Text & "issue:" & vbCrLf
    Text = Text & "  %last = icmp eq i64 %old, 9223372036854775807" & vbCrLf
    Text = Text & "  %increment = add i64 %old, 1" & vbCrLf
    Text = Text & "  %next = select i1 %last, i64 0, i64 %increment" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr @ube.thread.next, i64 %old, i64 %next seq_cst seq_cst" & vbCrLf
    Text = Text & "  %ok = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %ok, label %done, label %retry" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i64 %old" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i64 0" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.thread.record.new(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 16, i64 1)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %done, label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %data = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  ret ptr %data" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.thread.record.drop(ptr %ctx, ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %block = getelementptr %ube.block, ptr %record, i64 -1" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.thread.record.link(ptr %program, ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10" & vbCrLf
    Text = Text & "  %old = load atomic ptr, ptr %head acquire, align 8" & vbCrLf
    Text = Text & "  store ptr %old, ptr %record, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %record, ptr %head release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.thread.record.find(ptr %ctx, i64 %id) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %valid = icmp sgt i64 %id, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %head, label %failed" & vbCrLf
    Text = Text & "head:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 10" & vbCrLf
    Text = Text & "  %first = load atomic ptr, ptr %address acquire, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first, %head ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %failed" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %candidate = load i64, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %candidate, %id" & vbCrLf
    Text = Text & "  br i1 %same, label %done, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadTargets = Text
End Function

' Emits the reviewed NativeThreadIdentity runtime definitions.
Private Function NativeThreadIdentity() As String
    Dim Text As String
    Text = Text & "define internal ptr @ube.thread.current.record(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  %existing = load ptr, ptr %control, align 8" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %existing, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %known, label %allocate" & vbCrLf
    Text = Text & "known:" & vbCrLf
    Text = Text & "  ret ptr %existing" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.record.new(ptr %ctx)" & vbCrLf
    Text = Text & "  %allocated = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %allocated, label %identity, label %failed" & vbCrLf
    Text = Text & "identity:" & vbCrLf
    Text = Text & "  %id = call i64 @ube.thread.issue()" & vbCrLf
    Text = Text & "  %issued = icmp ne i64 %id, 0" & vbCrLf
    Text = Text & "  br i1 %issued, label %publish, label %discard" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  store i64 %id, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %state release, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  call void @ube.thread.record.link(ptr %program, ptr %record)" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  store ptr %record, ptr %control, align 8" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "discard:" & vbCrLf
    Text = Text & "  call void @ube.thread.record.drop(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define { i1, i64 } @ube.thread.current(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.current.record(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %done, label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %id = load i64, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.value(i64 %id)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %result" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  %failure = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 7)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %failure" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.thread.stop.requested(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  %record = load ptr, ptr %control, align 8" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %none" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %flag = getelementptr %ube.worker, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %stop = load atomic i64, ptr %flag seq_cst, align 8" & vbCrLf
    Text = Text & "  %requested = icmp ne i64 %stop, 0" & vbCrLf
    Text = Text & "  ret i1 %requested" & vbCrLf
    Text = Text & "none:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadIdentity = Text
End Function

' Emits the reviewed NativeThreadExecution runtime definitions.
Private Function NativeThreadExecution() As String
    Dim Text As String
    Text = Text & "define internal i32 @ube.thread.entry(ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  br label %gate" & vbCrLf
    Text = Text & "gate:" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  %started = icmp ne i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %started, label %run, label %yield" & vbCrLf
    Text = Text & "yield:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %gate" & vbCrLf
    Text = Text & "run:" & vbCrLf
    Text = Text & "  %ctx = getelementptr %ube.worker, ptr %record, i32 0, i32 8" & vbCrLf
    Text = Text & "  %entry.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 7" & vbCrLf
    Text = Text & "  %capture.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 6" & vbCrLf
    Text = Text & "  %procedure = load ptr, ptr %entry.ptr, align 8" & vbCrLf
    Text = Text & "  %capture = load ptr, ptr %capture.ptr, align 8" & vbCrLf
    Text = Text & "  %payload = getelementptr %ube.block, ptr %capture, i64 1" & vbCrLf
    Text = Text & "  %success = call i1 %procedure(ptr %ctx, ptr %payload)" & vbCrLf
    Text = Text & "  %error = load i64, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  %saved = select i1 %success, i64 0, i64 %error" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4" & vbCrLf
    Text = Text & "  store i64 %saved, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %capture)" & vbCrLf
    Text = Text & "  store ptr null, ptr %capture.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %active = getelementptr %ube.program, ptr %program, i32 0, i32 7" & vbCrLf
    Text = Text & "  %completion = select i1 %success, i64 2, i64 3" & vbCrLf
    Text = Text & "  store atomic i64 %completion, ptr %state release, align 8" & vbCrLf
    Text = Text & "  %previous = atomicrmw sub ptr %active, i64 1 acq_rel" & vbCrLf
    Text = Text & "  ret i32 0" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define { i1, i64 } @ube.thread.start(ptr %ctx, ptr %procedure, ptr %capture) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %null.procedure = icmp eq ptr %procedure, null" & vbCrLf
    Text = Text & "  %null.capture = icmp eq ptr %capture, null" & vbCrLf
    Text = Text & "  %invalid = or i1 %null.procedure, %null.capture" & vbCrLf
    Text = Text & "  br i1 %invalid, label %bad, label %current" & vbCrLf
    Text = Text & "current:" & vbCrLf
    Text = Text & "  %parent = call ptr @ube.thread.current.record(ptr %ctx)" & vbCrLf
    Text = Text & "  %parent.ok = icmp ne ptr %parent, null" & vbCrLf
    Text = Text & "  br i1 %parent.ok, label %allocate, label %memory" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.record.new(ptr %ctx)" & vbCrLf
    Text = Text & "  %allocated = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %allocated, label %reserve, label %memory" & vbCrLf
    Text = Text & "reserve:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7" & vbCrLf
    Text = Text & "  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %active = load atomic i64, ptr %active.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %closed = load atomic i64, ptr %closed.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %full = icmp uge i64 %active, 64" & vbCrLf
    Text = Text & "  %closing = icmp ne i64 %closed, 0" & vbCrLf
    Text = Text & "  %refused = or i1 %full, %closing" & vbCrLf
    Text = Text & "  br i1 %refused, label %unlock.discard, label %identity" & vbCrLf
    Text = Text & "identity:" & vbCrLf
    Text = Text & "  %id = call i64 @ube.thread.issue()" & vbCrLf
    Text = Text & "  %issued = icmp ne i64 %id, 0" & vbCrLf
    Text = Text & "  br i1 %issued, label %admitted, label %unlock.discard" & vbCrLf
    Text = Text & "admitted:" & vbCrLf
    Text = Text & "  %prior = atomicrmw add ptr %active.ptr, i64 1 acq_rel" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %capture.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 6" & vbCrLf
    Text = Text & "  %entry.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 7" & vbCrLf
    Text = Text & "  %thread = getelementptr %ube.worker, ptr %record, i32 0, i32 8" & vbCrLf
    Text = Text & "  store i64 %id, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %capture, ptr %capture.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %procedure, ptr %entry.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.init(ptr %thread, ptr %program, ptr %record)" & vbCrLf
    Text = Text & "  %handle = call ptr @ube.target.thread.start(ptr @ube.thread.entry, ptr %record)" & vbCrLf
    Text = Text & "  %created = icmp ne ptr %handle, null" & vbCrLf
    Text = Text & "  br i1 %created, label %publish, label %unreserve" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  store ptr %handle, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  call void @ube.thread.record.link(ptr %program, ptr %record)" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %state.ptr release, align 8" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.value(i64 %id)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %result" & vbCrLf
    Text = Text & "unreserve:" & vbCrLf
    Text = Text & "  %previous = atomicrmw sub ptr %active.ptr, i64 1 acq_rel" & vbCrLf
    Text = Text & "  call void @ube.thread.record.drop(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  %failure = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 57)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %failure" & vbCrLf
    Text = Text & "unlock.discard:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @ube.thread.record.drop(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  br label %memory" & vbCrLf
    Text = Text & "memory:" & vbCrLf
    Text = Text & "  %oom = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 7)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %oom" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  %bad.result = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %bad.result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadExecution = Text
End Function

' Emits the reviewed NativeThreadWaitOwners runtime definitions.
Private Function NativeThreadWaitOwners() As String
    Dim Text As String
    Text = Text & "; A native handle is closed only after every admitted waiter has stopped using it." & vbCrLf
    Text = Text & "define internal i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 %joined) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %waiters = getelementptr %ube.worker, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %closing = getelementptr %ube.worker, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  %finished = getelementptr %ube.worker, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %count = load i64, ptr %waiters, align 8" & vbCrLf
    Text = Text & "  %less = sub i64 %count, 1" & vbCrLf
    Text = Text & "  store i64 %less, ptr %waiters, align 8" & vbCrLf
    Text = Text & "  %old.done = load i64, ptr %finished, align 8" & vbCrLf
    Text = Text & "  %done = select i1 %joined, i64 1, i64 %old.done" & vbCrLf
    Text = Text & "  store i64 %done, ptr %finished, align 8" & vbCrLf
    Text = Text & "  %busy = load i64, ptr %closing, align 8" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  %last = icmp eq i64 %less, 0" & vbCrLf
    Text = Text & "  %native.done = icmp eq i64 %done, 1" & vbCrLf
    Text = Text & "  %idle = icmp eq i64 %busy, 0" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %handle, null" & vbCrLf
    Text = Text & "  %safe = and i1 %last, %native.done" & vbCrLf
    Text = Text & "  %owned = and i1 %idle, %exists" & vbCrLf
    Text = Text & "  %release = and i1 %safe, %owned" & vbCrLf
    Text = Text & "  br i1 %release, label %claim, label %keep" & vbCrLf
    Text = Text & "claim:" & vbCrLf
    Text = Text & "  store i64 1, ptr %closing, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %ok = call i1 @ube.target.thread.close(ptr %handle)" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %retained = select i1 %ok, ptr null, ptr %handle" & vbCrLf
    Text = Text & "  store ptr %retained, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %closing, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "keep:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Reads the release-published outcome independently of the persistent Err number." & vbCrLf
    Text = Text & "define internal { i1, i64 } @ube.thread.completion(ptr %ctx, ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  %failed = icmp eq i64 %value, 3" & vbCrLf
    Text = Text & "  br i1 %failed, label %failure, label %success" & vbCrLf
    Text = Text & "failure:" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4" & vbCrLf
    Text = Text & "  %error = load i64, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 %error)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %bad" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  ret { i1, i64 } { i1 true, i64 1 }" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadWaitOwners = Text
End Function

' Emits the reviewed NativeThreadWaiting runtime definitions.
Private Function NativeThreadWaiting() As String
    Dim Text As String
    Text = Text & "define internal { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 %timeout, i1 %observe.stop) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %invalid.timeout = icmp slt i64 %timeout, -1" & vbCrLf
    Text = Text & "  br i1 %invalid.timeout, label %invalid, label %lookup" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %self, label %invalid" & vbCrLf
    Text = Text & "self:" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  %current = load ptr, ptr %control, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %current, %record" & vbCrLf
    Text = Text & "  br i1 %same, label %invalid, label %acquire" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  %waiters = getelementptr %ube.worker, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %finished = getelementptr %ube.worker, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  %closing.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %done = load i64, ptr %finished, align 8" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  %closing = load i64, ptr %closing.ptr, align 8" & vbCrLf
    Text = Text & "  %already = icmp eq i64 %done, 1" & vbCrLf
    Text = Text & "  %native = icmp ne ptr %handle, null" & vbCrLf
    Text = Text & "  %idle = icmp eq i64 %closing, 0" & vbCrLf
    Text = Text & "  %borrow = and i1 %native, %idle" & vbCrLf
    Text = Text & "  br i1 %borrow, label %retain, label %unlocked" & vbCrLf
    Text = Text & "retain:" & vbCrLf
    Text = Text & "  %count = load i64, ptr %waiters, align 8" & vbCrLf
    Text = Text & "  %more = add i64 %count, 1" & vbCrLf
    Text = Text & "  store i64 %more, ptr %waiters, align 8" & vbCrLf
    Text = Text & "  br label %unlocked" & vbCrLf
    Text = Text & "unlocked:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br i1 %already, label %already.complete, label %clock" & vbCrLf
    Text = Text & "already.complete:" & vbCrLf
    Text = Text & "  br i1 %borrow, label %release.joined, label %completed" & vbCrLf
    Text = Text & "clock:" & vbCrLf
    Text = Text & "  %started = call i64 @GetTickCount64()" & vbCrLf
    Text = Text & "  %forever = icmp eq i64 %timeout, -1" & vbCrLf
    Text = Text & "  br label %poll" & vbCrLf
    Text = Text & "poll:" & vbCrLf
    Text = Text & "  br i1 %borrow, label %native.poll, label %root.poll" & vbCrLf
    Text = Text & "native.poll:" & vbCrLf
    Text = Text & "  %status = call i32 @ube.target.thread.wait(ptr %handle, i32 0)" & vbCrLf
    Text = Text & "  %joined = icmp eq i32 %status, 0" & vbCrLf
    Text = Text & "  br i1 %joined, label %release.joined, label %native.status" & vbCrLf
    Text = Text & "native.status:" & vbCrLf
    Text = Text & "  %waiting = icmp eq i32 %status, 258" & vbCrLf
    Text = Text & "  br i1 %waiting, label %pending, label %release.failed" & vbCrLf
    Text = Text & "root.poll:" & vbCrLf
    Text = Text & "  %state = load atomic i64, ptr %state.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %complete = icmp uge i64 %state, 2" & vbCrLf
    Text = Text & "  br i1 %complete, label %completed, label %pending" & vbCrLf
    Text = Text & "pending:" & vbCrLf
    Text = Text & "  %requested = call i1 @ube.thread.stop.requested(ptr %ctx)" & vbCrLf
    Text = Text & "  %stop = and i1 %requested, %observe.stop" & vbCrLf
    Text = Text & "  %now = call i64 @GetTickCount64()" & vbCrLf
    Text = Text & "  %elapsed = sub i64 %now, %started" & vbCrLf
    Text = Text & "  %deadline = icmp uge i64 %elapsed, %timeout" & vbCrLf
    Text = Text & "  %bounded = xor i1 %forever, true" & vbCrLf
    Text = Text & "  %expired = and i1 %bounded, %deadline" & vbCrLf
    Text = Text & "  %interrupted = or i1 %stop, %expired" & vbCrLf
    Text = Text & "  br i1 %interrupted, label %interrupted.wait, label %pause" & vbCrLf
    Text = Text & "pause:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 1)" & vbCrLf
    Text = Text & "  br label %poll" & vbCrLf
    Text = Text & "interrupted.wait:" & vbCrLf
    Text = Text & "  br i1 %borrow, label %release.timeout, label %zero" & vbCrLf
    Text = Text & "release.timeout:" & vbCrLf
    Text = Text & "  %timeout.closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 false)" & vbCrLf
    Text = Text & "  br i1 %timeout.closed, label %zero, label %native.failed" & vbCrLf
    Text = Text & "release.failed:" & vbCrLf
    Text = Text & "  %failed.closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 false)" & vbCrLf
    Text = Text & "  br label %native.failed" & vbCrLf
    Text = Text & "release.joined:" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 true)" & vbCrLf
    Text = Text & "  br i1 %closed, label %completed, label %joined.cleanup.failed" & vbCrLf
    Text = Text & "joined.cleanup.failed:" & vbCrLf
    Text = Text & "  %joined.state = load atomic i64, ptr %state.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %worker.failed = icmp eq i64 %joined.state, 3" & vbCrLf
    Text = Text & "  br i1 %worker.failed, label %completed, label %native.failed" & vbCrLf
    Text = Text & "completed:" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.completion(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret { i1, i64 } { i1 true, i64 0 }" & vbCrLf
    Text = Text & "invalid:" & vbCrLf
    Text = Text & "  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %bad" & vbCrLf
    Text = Text & "native.failed:" & vbCrLf
    Text = Text & "  %os = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 57)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %os" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadWaiting = Text
End Function

' Emits the reviewed NativeThreadControl runtime definitions.
Private Function NativeThreadControl() As String
    Dim Text As String
    Text = Text & "define { i1, i64 } @ube.thread.wait(ptr %ctx, i64 %id, i64 %timeout) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 %timeout, i1 true)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define { i1, i64 } @ube.thread.alive(ptr %ctx, i64 %id) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %invalid" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  %running = icmp ult i64 %value, 2" & vbCrLf
    Text = Text & "  %answer = select i1 %running, i64 -1, i64 0" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.value(i64 %answer)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %result" & vbCrLf
    Text = Text & "invalid:" & vbCrLf
    Text = Text & "  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %bad" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define { i1, i64 } @ube.thread.request.stop(ptr %ctx, i64 %id) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %invalid" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  %running = icmp ult i64 %value, 2" & vbCrLf
    Text = Text & "  br i1 %running, label %request, label %done" & vbCrLf
    Text = Text & "request:" & vbCrLf
    Text = Text & "  %flag = getelementptr %ube.worker, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %flag seq_cst, align 8" & vbCrLf
    Text = Text & "  ret { i1, i64 } { i1 true, i64 1 }" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret { i1, i64 } { i1 true, i64 0 }" & vbCrLf
    Text = Text & "invalid:" & vbCrLf
    Text = Text & "  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)" & vbCrLf
    Text = Text & "  ret { i1, i64 } %bad" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & vbCrLf
    NativeThreadControl = Text
End Function

' Emits the reviewed NativeThreadShutdown runtime definitions.
Private Function NativeThreadShutdown() As String
    Dim Text As String
    Text = Text & "; The generated process entry publishes Main's fresh outcome before waiting for workers." & vbCrLf
    Text = Text & "define void @ube.thread.root.complete(ptr %ctx, i1 %success) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  %record = load ptr, ptr %control, align 8" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %publish, label %done" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4" & vbCrLf
    Text = Text & "  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %number = load i64, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  %saved = select i1 %success, i64 0, i64 %number" & vbCrLf
    Text = Text & "  %state = select i1 %success, i64 2, i64 3" & vbCrLf
    Text = Text & "  store i64 %saved, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %state, ptr %state.ptr release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Main's return closes no live worker prematurely, including workers with ignored IDs." & vbCrLf
    Text = Text & "define i1 @ube.thread.drain(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %saved.error = load i64, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10" & vbCrLf
    Text = Text & "  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7" & vbCrLf
    Text = Text & "  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  %self = load ptr, ptr %control, align 8" & vbCrLf
    Text = Text & "  br label %round" & vbCrLf
    Text = Text & "round:" & vbCrLf
    Text = Text & "  %first = load atomic ptr, ptr %head acquire, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first, %round ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %quiescent" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %record, %self" & vbCrLf
    Text = Text & "  br i1 %same, label %advance, label %join" & vbCrLf
    Text = Text & "join:" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %id = load i64, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 -1, i1 false)" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %released = icmp eq ptr %handle, null" & vbCrLf
    Text = Text & "  br i1 %released, label %advance, label %retained" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "quiescent:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %active = load atomic i64, ptr %active.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %active, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %close, label %again" & vbCrLf
    Text = Text & "close:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %closed.ptr release, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  store i64 %saved.error, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "again:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @Sleep(i32 1)" & vbCrLf
    Text = Text & "  br label %round" & vbCrLf
    Text = Text & "retained:" & vbCrLf
    Text = Text & "  %remaining = load atomic i64, ptr %active.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %workers.live = icmp ne i64 %remaining, 0" & vbCrLf
    Text = Text & "  br i1 %workers.live, label %retry.observation, label %failed" & vbCrLf
    Text = Text & "retry.observation:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 1)" & vbCrLf
    Text = Text & "  br label %round" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  store i64 %saved.error, ptr %ctx, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Disposes completion records only after no worker or waiter can access them." & vbCrLf
    Text = Text & "define i1 @ube.thread.program.dispose(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7" & vbCrLf
    Text = Text & "  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %active = load atomic i64, ptr %active.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %active, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %inspect.head, label %busy" & vbCrLf
    Text = Text & "inspect.head:" & vbCrLf
    Text = Text & "  %first = load atomic ptr, ptr %head acquire, align 8" & vbCrLf
    Text = Text & "  br label %inspect" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first, %inspect.head ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %ownership, label %close.admission" & vbCrLf
    Text = Text & "ownership:" & vbCrLf
    Text = Text & "  %waiters.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %closing.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  %waiters = load i64, ptr %waiters.ptr, align 8" & vbCrLf
    Text = Text & "  %closing = load i64, ptr %closing.ptr, align 8" & vbCrLf
    Text = Text & "  %waiting = icmp ne i64 %waiters, 0" & vbCrLf
    Text = Text & "  %releasing = icmp ne i64 %closing, 0" & vbCrLf
    Text = Text & "  %owned = or i1 %waiting, %releasing" & vbCrLf
    Text = Text & "  br i1 %owned, label %busy, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  br label %inspect" & vbCrLf
    Text = Text & "close.admission:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %closed.ptr release, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %release" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  %candidate = phi ptr [ %first, %close.admission ], [ %following, %released ]" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %candidate, null" & vbCrLf
    Text = Text & "  br i1 %present, label %handle, label %discard.head" & vbCrLf
    Text = Text & "handle:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.worker, ptr %candidate, i32 0, i32 2" & vbCrLf
    Text = Text & "  %native = load ptr, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  %has.handle = icmp ne ptr %native, null" & vbCrLf
    Text = Text & "  br i1 %has.handle, label %close.handle, label %released" & vbCrLf
    Text = Text & "close.handle:" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.target.thread.close(ptr %native)" & vbCrLf
    Text = Text & "  br i1 %closed, label %clear, label %failed" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  store ptr null, ptr %handle.ptr, align 8" & vbCrLf
    Text = Text & "  br label %released" & vbCrLf
    Text = Text & "released:" & vbCrLf
    Text = Text & "  %following = load ptr, ptr %candidate, align 8" & vbCrLf
    Text = Text & "  br label %release" & vbCrLf
    Text = Text & "discard.head:" & vbCrLf
    Text = Text & "  store atomic ptr null, ptr %head release, align 8" & vbCrLf
    Text = Text & "  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3" & vbCrLf
    Text = Text & "  store ptr null, ptr %control, align 8" & vbCrLf
    Text = Text & "  br label %discard" & vbCrLf
    Text = Text & "discard:" & vbCrLf
    Text = Text & "  %item = phi ptr [ %first, %discard.head ], [ %after, %drop ]" & vbCrLf
    Text = Text & "  %remains = icmp ne ptr %item, null" & vbCrLf
    Text = Text & "  br i1 %remains, label %drop, label %done" & vbCrLf
    Text = Text & "drop:" & vbCrLf
    Text = Text & "  %after = load ptr, ptr %item, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.record.drop(ptr %ctx, ptr %item)" & vbCrLf
    Text = Text & "  br label %discard" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "busy:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeThreadShutdown = Text
End Function
