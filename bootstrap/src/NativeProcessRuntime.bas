Attribute VB_Name = "NativeProcessRuntime"
Option Explicit

' Emits owned Windows process operations with explicit inheritance and retryable native cleanup.

' Composes fixed target mechanics; timeout, logging and publication policy remain ordinary UBE.
Public Function NativeProcessIR() As String
    NativeProcessIR = NativeProcessIR & NativeProcessTargets()
    NativeProcessIR = NativeProcessIR & NativeProcessOwners()
    NativeProcessIR = NativeProcessIR & NativeProcessStart()
    NativeProcessIR = NativeProcessIR & NativeProcessWait()
    NativeProcessIR = NativeProcessIR & NativeProcessRelease()
End Function

' Emits the reviewed NativeProcessTargets target definitions.
Private Function NativeProcessTargets() As String
    Dim Text As String
    Text = Text & "%ube.process = type { ptr, ptr, ptr, ptr, ptr, i64, i64, i64, i64 }" & vbCrLf
    Text = Text & "@ube.process.nullname = private constant [4 x i16] [i16 78, i16 85, i16 76, i16 0]" & vbCrLf
    Text = Text & "declare dllimport ptr @GetCurrentProcess()" & vbCrLf
    Text = Text & "declare dllimport i32 @DuplicateHandle(ptr, ptr, ptr, ptr, i32, i32, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @CreateProcessW(ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @InitializeProcThreadAttributeList(ptr, i32, i32, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @UpdateProcThreadAttribute(ptr, i32, i64, ptr, i64, ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport void @DeleteProcThreadAttributeList(ptr)" & vbCrLf
    Text = Text & "declare dllimport ptr @CreateJobObjectW(ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @SetInformationJobObject(ptr, i32, ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @AssignProcessToJobObject(ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @ResumeThread(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @WaitForSingleObject(ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @GetExitCodeProcess(ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @QueryInformationJobObject(ptr, i32, ptr, i32, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @TerminateJobObject(ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @TerminateProcess(ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport void @Sleep(i32)" & vbCrLf
    Text = Text & "define i1 @ube.target.process.duplicate(ptr %source, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %self = call ptr @GetCurrentProcess()" & vbCrLf
    Text = Text & "  %result = call i32 @DuplicateHandle(ptr %self, ptr %source, ptr %self, ptr %output, i32 0, i32 1, i32 2)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define ptr @ube.target.process.nullinput() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %security = alloca { i32, ptr, i32 }, align 8" & vbCrLf
    Text = Text & "  %descriptor = getelementptr { i32, ptr, i32 }, ptr %security, i32 0, i32 1" & vbCrLf
    Text = Text & "  %inherit = getelementptr { i32, ptr, i32 }, ptr %security, i32 0, i32 2" & vbCrLf
    Text = Text & "  store i32 24, ptr %security" & vbCrLf
    Text = Text & "  store ptr null, ptr %descriptor" & vbCrLf
    Text = Text & "  store i32 1, ptr %inherit" & vbCrLf
    Text = Text & "  %result = call ptr @CreateFileW(ptr @ube.process.nullname, i32 -2147483648, i32 3, ptr %security, i32 3, i32 128, ptr null)" & vbCrLf
    Text = Text & "  ret ptr %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define ptr @ube.target.process.job() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call ptr @CreateJobObjectW(ptr null, ptr null)" & vbCrLf
    Text = Text & "  ret ptr %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.limit(ptr %job, ptr %information) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @SetInformationJobObject(ptr %job, i32 9, ptr %information, i32 144)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.attributes(ptr %list, ptr %size) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @InitializeProcThreadAttributeList(ptr %list, i32 1, i32 0, ptr %size)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.handles(ptr %list, ptr %handles) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @UpdateProcThreadAttribute(ptr %list, i32 0, i64 131074, ptr %handles, i64 16, ptr null, ptr null)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.target.process.deleteattributes(ptr %list) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  call void @DeleteProcThreadAttributeList(ptr %list)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.create(ptr %app, ptr %command, ptr %directory, ptr %startup, ptr %information) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @CreateProcessW(ptr %app, ptr %command, ptr null, ptr null, i32 1, i32 134742020, ptr null, ptr %directory, ptr %startup, ptr %information)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.assign(ptr %job, ptr %process) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @AssignProcessToJobObject(ptr %job, ptr %process)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.resume(ptr %thread) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @ResumeThread(ptr %thread)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, -1" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.process.wait(ptr %process, i32 %milliseconds) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @WaitForSingleObject(ptr %process, i32 %milliseconds)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.exit(ptr %process, ptr %code) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @GetExitCodeProcess(ptr %process, ptr %code)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.accounting(ptr %job, ptr %information) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @QueryInformationJobObject(ptr %job, i32 1, ptr %information, i32 48, ptr null)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.terminatejob(ptr %job) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @TerminateJobObject(ptr %job, i32 1)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.terminate(ptr %process) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @TerminateProcess(ptr %process, i32 1)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.process.close(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @CloseHandle(ptr %handle)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %result, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.target.process.sleep(i32 %milliseconds) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 %milliseconds)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeProcessTargets = Text
End Function

' Emits the reviewed NativeProcessOwners target definitions.
Private Function NativeProcessOwners() As String
    Dim Text As String
    Text = Text & "define internal void @ube.process.zero(ptr %storage, i64 %length) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %clear" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  %index = phi i64 [0, %entry], [%next, %clear]" & vbCrLf
    Text = Text & "  %cell = getelementptr i8, ptr %storage, i64 %index" & vbCrLf
    Text = Text & "  store volatile i8 0, ptr %cell" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %length" & vbCrLf
    Text = Text & "  br i1 %more, label %clear, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %actual = load atomic i64, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %correct = icmp eq i64 %actual, 4" & vbCrLf
    Text = Text & "  br i1 %correct, label %done, label %wrong" & vbCrLf
    Text = Text & "wrong:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %slot" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.process.state(ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  %block = load ptr, ptr %scratch.ptr" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  ret ptr %state" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i32 @ube.process.command(ptr %array, ptr %packed, ptr %wide) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %length, 0" & vbCrLf
    Text = Text & "  %large = icmp ugt i64 %length, 131072" & vbCrLf
    Text = Text & "  %invalid = or i1 %empty, %large" & vbCrLf
    Text = Text & "  br i1 %invalid, label %failed, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %copy" & vbCrLf
    Text = Text & "copy:" & vbCrLf
    Text = Text & "  %index = phi i64 [0, %prepare], [%next, %more]" & vbCrLf
    Text = Text & "  %source = getelementptr i64, ptr %data, i64 %index" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %source monotonic, align 8" & vbCrLf
    Text = Text & "  %nul = icmp eq i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %nul, label %failed, label %pack" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %byte = trunc i64 %value to i8" & vbCrLf
    Text = Text & "  %destination = getelementptr i8, ptr %packed, i64 %index" & vbCrLf
    Text = Text & "  store volatile i8 %byte, ptr %destination" & vbCrLf
    Text = Text & "  br label %more" & vbCrLf
    Text = Text & "more:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %remaining = icmp ult i64 %next, %length" & vbCrLf
    Text = Text & "  br i1 %remaining, label %copy, label %convert" & vbCrLf
    Text = Text & "convert:" & vbCrLf
    Text = Text & "  %bytes = trunc i64 %length to i32" & vbCrLf
    Text = Text & "  %units = call i32 @ube.target.file.utf8(ptr %packed, i32 %bytes, ptr %wide, i32 32766)" & vbCrLf
    Text = Text & "  %valid = icmp sgt i32 %units, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %finish, label %failed" & vbCrLf
    Text = Text & "finish:" & vbCrLf
    Text = Text & "  %units64 = zext i32 %units to i64" & vbCrLf
    Text = Text & "  %end = getelementptr i16, ptr %wide, i64 %units64" & vbCrLf
    Text = Text & "  store i16 0, ptr %end" & vbCrLf
    Text = Text & "  ret i32 %units" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i32 -1" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i64 @ube.process.active(ptr %state) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %information = alloca [48 x i8], align 8" & vbCrLf
    Text = Text & "  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %attached = load atomic i64, ptr %attached.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %contained = icmp ne i64 %attached, 0" & vbCrLf
    Text = Text & "  br i1 %contained, label %query, label %unattached" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %job = load ptr, ptr %state" & vbCrLf
    Text = Text & "  %ok = call i1 @ube.target.process.accounting(ptr %job, ptr %information)" & vbCrLf
    Text = Text & "  br i1 %ok, label %count, label %failed" & vbCrLf
    Text = Text & "count:" & vbCrLf
    Text = Text & "  %active.ptr = getelementptr i8, ptr %information, i64 40" & vbCrLf
    Text = Text & "  %active32 = load i32, ptr %active.ptr" & vbCrLf
    Text = Text & "  %active = zext i32 %active32 to i64" & vbCrLf
    Text = Text & "  ret i64 %active" & vbCrLf
    Text = Text & "unattached:" & vbCrLf
    Text = Text & "  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  %process = load ptr, ptr %process.ptr" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %process, null" & vbCrLf
    Text = Text & "  %exited.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 6" & vbCrLf
    Text = Text & "  %exited = load atomic i64, ptr %exited.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %live = icmp eq i64 %exited, 0" & vbCrLf
    Text = Text & "  %running = and i1 %exists, %live" & vbCrLf
    Text = Text & "  %result = zext i1 %running to i64" & vbCrLf
    Text = Text & "  ret i64 %result" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i64 -1" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i32 @ube.process.observe(ptr %state, i32 %milliseconds) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %native.exit = alloca i32, align 4" & vbCrLf
    Text = Text & "  %exit.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 5" & vbCrLf
    Text = Text & "  %exited.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 6" & vbCrLf
    Text = Text & "  %exited = load atomic i64, ptr %exited.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %cached = icmp ne i64 %exited, 0" & vbCrLf
    Text = Text & "  br i1 %cached, label %query, label %process" & vbCrLf
    Text = Text & "process:" & vbCrLf
    Text = Text & "  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %process.ptr" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %handle, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %not.created, label %wait" & vbCrLf
    Text = Text & "not.created:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %exit.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %exited.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  br label %query" & vbCrLf
    Text = Text & "wait:" & vbCrLf
    Text = Text & "  %result = call i32 @ube.target.process.wait(ptr %handle, i32 %milliseconds)" & vbCrLf
    Text = Text & "  %done = icmp eq i32 %result, 0" & vbCrLf
    Text = Text & "  br i1 %done, label %read.exit, label %timeout" & vbCrLf
    Text = Text & "timeout:" & vbCrLf
    Text = Text & "  %pending = icmp eq i32 %result, 258" & vbCrLf
    Text = Text & "  br i1 %pending, label %query, label %failed" & vbCrLf
    Text = Text & "read.exit:" & vbCrLf
    Text = Text & "  %read = call i1 @ube.target.process.exit(ptr %handle, ptr %native.exit)" & vbCrLf
    Text = Text & "  br i1 %read, label %cache, label %failed" & vbCrLf
    Text = Text & "cache:" & vbCrLf
    Text = Text & "  %code32 = load i32, ptr %native.exit" & vbCrLf
    Text = Text & "  %code = sext i32 %code32 to i64" & vbCrLf
    Text = Text & "  store atomic i64 %code, ptr %exit.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %exited.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  br label %query" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %active = call i64 @ube.process.active(ptr %state)" & vbCrLf
    Text = Text & "  %bad.query = icmp slt i64 %active, 0" & vbCrLf
    Text = Text & "  br i1 %bad.query, label %failed, label %pause.check" & vbCrLf
    Text = Text & "pause.check:" & vbCrLf
    Text = Text & "  %nonempty = icmp ne i64 %active, 0" & vbCrLf
    Text = Text & "  %positive.wait = icmp ugt i32 %milliseconds, 0" & vbCrLf
    Text = Text & "  %wait.descendants = and i1 %cached, %nonempty" & vbCrLf
    Text = Text & "  %pause = and i1 %wait.descendants, %positive.wait" & vbCrLf
    Text = Text & "  br i1 %pause, label %sleep, label %finish" & vbCrLf
    Text = Text & "sleep:" & vbCrLf
    Text = Text & "  call void @ube.target.process.sleep(i32 %milliseconds)" & vbCrLf
    Text = Text & "  %after = call i64 @ube.process.active(ptr %state)" & vbCrLf
    Text = Text & "  %bad.after = icmp slt i64 %after, 0" & vbCrLf
    Text = Text & "  br i1 %bad.after, label %failed, label %finish" & vbCrLf
    Text = Text & "finish:" & vbCrLf
    Text = Text & "  %current = phi i64 [%active, %pause.check], [%after, %sleep]" & vbCrLf
    Text = Text & "  %root.state = load atomic i64, ptr %exited.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %root.done = icmp ne i64 %root.state, 0" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %current, 0" & vbCrLf
    Text = Text & "  %complete = and i1 %root.done, %empty" & vbCrLf
    Text = Text & "  %value = zext i1 %complete to i32" & vbCrLf
    Text = Text & "  ret i32 %value" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i32 -1" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeProcessOwners = Text
End Function

' Emits the reviewed NativeProcessStart target definitions.
Private Function NativeProcessStart() As String
    Dim Text As String
    Text = Text & "define internal i1 @ube.process.start.pinned(ptr %ctx, ptr %app, ptr %command, ptr %directory, i64 %log.token, ptr %token.out, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %attribute.size = alloca i64, align 8" & vbCrLf
    Text = Text & "  %attribute.live = alloca i1, align 1" & vbCrLf
    Text = Text & "  %inherited = alloca [2 x ptr], align 8" & vbCrLf
    Text = Text & "  store i1 false, ptr %attribute.live" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %token.out, %failure" & vbCrLf
    Text = Text & "  %null.token = icmp eq ptr %token.out, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %a = call i1 @ube.file.overlaps(ptr %app, ptr %token.out)" & vbCrLf
    Text = Text & "  %b = call i1 @ube.file.overlaps(ptr %app, ptr %failure)" & vbCrLf
    Text = Text & "  %c = call i1 @ube.file.overlaps(ptr %command, ptr %token.out)" & vbCrLf
    Text = Text & "  %d = call i1 @ube.file.overlaps(ptr %command, ptr %failure)" & vbCrLf
    Text = Text & "  %e = call i1 @ube.file.overlaps(ptr %directory, ptr %token.out)" & vbCrLf
    Text = Text & "  %f = call i1 @ube.file.overlaps(ptr %directory, ptr %failure)" & vbCrLf
    Text = Text & "  %ab = or i1 %a, %b" & vbCrLf
    Text = Text & "  %cd = or i1 %c, %d" & vbCrLf
    Text = Text & "  %ef = or i1 %e, %f" & vbCrLf
    Text = Text & "  %abcd = or i1 %ab, %cd" & vbCrLf
    Text = Text & "  %overlap = or i1 %abcd, %ef" & vbCrLf
    Text = Text & "  %nulls = or i1 %null.token, %null.failure" & vbCrLf
    Text = Text & "  %bad.scalar = or i1 %same, %nulls" & vbCrLf
    Text = Text & "  %bad = or i1 %bad.scalar, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad, label %alias.fail, label %validate" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "validate:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %old = load atomic i64, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  %available = icmp eq i64 %old, 0" & vbCrLf
    Text = Text & "  br i1 %available, label %reserve, label %request.fail" & vbCrLf
    Text = Text & "reserve:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.reserve(ptr %ctx)" & vbCrLf
    Text = Text & "  %no.slot = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %no.slot, label %memory.fail, label %allocate" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 27280, i64 1)" & vbCrLf
    Text = Text & "  %no.block = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.block, label %empty.release, label %prepare" & vbCrLf
    Text = Text & "empty.release:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  br label %memory.fail" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  store ptr %block, ptr %scratch.ptr" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  call void @ube.process.zero(ptr %state, i64 72)" & vbCrLf
    Text = Text & "  %wide.app = getelementptr i8, ptr %state, i64 128" & vbCrLf
    Text = Text & "  %wide.directory = getelementptr i8, ptr %state, i64 8448" & vbCrLf
    Text = Text & "  %wide.command = getelementptr i8, ptr %state, i64 16896" & vbCrLf
    Text = Text & "  %packed = getelementptr i8, ptr %state, i64 82688" & vbCrLf
    Text = Text & "  %startup = getelementptr i8, ptr %state, i64 213760" & vbCrLf
    Text = Text & "  %information = getelementptr i8, ptr %state, i64 213872" & vbCrLf
    Text = Text & "  %job.information = getelementptr i8, ptr %state, i64 213896" & vbCrLf
    Text = Text & "  %attributes = getelementptr i8, ptr %state, i64 214144" & vbCrLf
    Text = Text & "  %app.length = call i32 @ube.path.decode(ptr %app, ptr %packed, ptr %wide.app)" & vbCrLf
    Text = Text & "  %app.valid = icmp sgt i32 %app.length, 0" & vbCrLf
    Text = Text & "  br i1 %app.valid, label %directory.decode, label %invalid.private" & vbCrLf
    Text = Text & "directory.decode:" & vbCrLf
    Text = Text & "  %directory.length = call i32 @ube.path.decode(ptr %directory, ptr %packed, ptr %wide.directory)" & vbCrLf
    Text = Text & "  %directory.valid = icmp sgt i32 %directory.length, 0" & vbCrLf
    Text = Text & "  br i1 %directory.valid, label %command.decode, label %invalid.private" & vbCrLf
    Text = Text & "command.decode:" & vbCrLf
    Text = Text & "  %command.length = call i32 @ube.process.command(ptr %command, ptr %packed, ptr %wide.command)" & vbCrLf
    Text = Text & "  %command.valid = icmp sgt i32 %command.length, 0" & vbCrLf
    Text = Text & "  br i1 %command.valid, label %identity, label %invalid.private" & vbCrLf
    Text = Text & "identity:" & vbCrLf
    Text = Text & "  %token = call i64 @ube.resource.token()" & vbCrLf
    Text = Text & "  %valid.token = icmp ne i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %valid.token, label %publish, label %exhausted.private" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr null, ptr %handle.ptr" & vbCrLf
    Text = Text & "  store atomic i64 4, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  %thread.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %input.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %log.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %started.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 7" & vbCrLf
    Text = Text & "  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %job = call ptr @ube.target.process.job()" & vbCrLf
    Text = Text & "  store ptr %job, ptr %state" & vbCrLf
    Text = Text & "  %job.failed = icmp eq ptr %job, null" & vbCrLf
    Text = Text & "  br i1 %job.failed, label %io.fail, label %job.limit" & vbCrLf
    Text = Text & "job.limit:" & vbCrLf
    Text = Text & "  call void @ube.process.zero(ptr %job.information, i64 144)" & vbCrLf
    Text = Text & "  %limit.flags = getelementptr i8, ptr %job.information, i64 16" & vbCrLf
    Text = Text & "  store i32 8192, ptr %limit.flags" & vbCrLf
    Text = Text & "  %limited = call i1 @ube.target.process.limit(ptr %job, ptr %job.information)" & vbCrLf
    Text = Text & "  br i1 %limited, label %input, label %io.fail" & vbCrLf
    Text = Text & "input:" & vbCrLf
    Text = Text & "  %input.handle = call ptr @ube.target.process.nullinput()" & vbCrLf
    Text = Text & "  %invalid.input = icmp eq ptr %input.handle, inttoptr (i64 -1 to ptr)" & vbCrLf
    Text = Text & "  %null.input = icmp eq ptr %input.handle, null" & vbCrLf
    Text = Text & "  %bad.input = or i1 %invalid.input, %null.input" & vbCrLf
    Text = Text & "  br i1 %bad.input, label %io.fail, label %input.owned" & vbCrLf
    Text = Text & "input.owned:" & vbCrLf
    Text = Text & "  store ptr %input.handle, ptr %input.ptr" & vbCrLf
    Text = Text & "  %log.slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %log.token, ptr %failure)" & vbCrLf
    Text = Text & "  %no.log = icmp eq ptr %log.slot, null" & vbCrLf
    Text = Text & "  br i1 %no.log, label %retain.failure, label %log.kind" & vbCrLf
    Text = Text & "log.kind:" & vbCrLf
    Text = Text & "  %log.kind.ptr = getelementptr %ube.resource, ptr %log.slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %log.mode = load atomic i64, ptr %log.kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %writable = icmp eq i64 %log.mode, 2" & vbCrLf
    Text = Text & "  br i1 %writable, label %duplicate, label %wrong.log" & vbCrLf
    Text = Text & "wrong.log:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %log.slot)" & vbCrLf
    Text = Text & "  %wrong.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  br label %retain.failure" & vbCrLf
    Text = Text & "duplicate:" & vbCrLf
    Text = Text & "  %log.handle.ptr = getelementptr %ube.resource, ptr %log.slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %log.handle = load ptr, ptr %log.handle.ptr" & vbCrLf
    Text = Text & "  %duplicated = call i1 @ube.target.process.duplicate(ptr %log.handle, ptr %log.ptr)" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %log.slot)" & vbCrLf
    Text = Text & "  br i1 %duplicated, label %attribute.measure, label %io.fail" & vbCrLf
    Text = Text & "attribute.measure:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %attribute.size monotonic, align 8" & vbCrLf
    Text = Text & "  %measurement = call i1 @ube.target.process.attributes(ptr null, ptr %attribute.size)" & vbCrLf
    Text = Text & "  %size = load atomic i64, ptr %attribute.size monotonic, align 8" & vbCrLf
    Text = Text & "  %positive = icmp ugt i64 %size, 0" & vbCrLf
    Text = Text & "  %bounded = icmp ule i64 %size, 4096" & vbCrLf
    Text = Text & "  %valid.size = and i1 %positive, %bounded" & vbCrLf
    Text = Text & "  %expected.failure = xor i1 %measurement, true" & vbCrLf
    Text = Text & "  %measured = and i1 %valid.size, %expected.failure" & vbCrLf
    Text = Text & "  br i1 %measured, label %attribute.initialize, label %io.fail" & vbCrLf
    Text = Text & "attribute.initialize:" & vbCrLf
    Text = Text & "  %initialized = call i1 @ube.target.process.attributes(ptr %attributes, ptr %attribute.size)" & vbCrLf
    Text = Text & "  br i1 %initialized, label %attribute.values, label %io.fail" & vbCrLf
    Text = Text & "attribute.values:" & vbCrLf
    Text = Text & "  store i1 true, ptr %attribute.live" & vbCrLf
    Text = Text & "  %private.log = load ptr, ptr %log.ptr" & vbCrLf
    Text = Text & "  %second.handle = getelementptr ptr, ptr %inherited, i64 1" & vbCrLf
    Text = Text & "  store ptr %input.handle, ptr %inherited" & vbCrLf
    Text = Text & "  store ptr %private.log, ptr %second.handle" & vbCrLf
    Text = Text & "  %listed = call i1 @ube.target.process.handles(ptr %attributes, ptr %inherited)" & vbCrLf
    Text = Text & "  br i1 %listed, label %startup.prepare, label %io.fail" & vbCrLf
    Text = Text & "startup.prepare:" & vbCrLf
    Text = Text & "  call void @ube.process.zero(ptr %startup, i64 112)" & vbCrLf
    Text = Text & "  call void @ube.process.zero(ptr %information, i64 24)" & vbCrLf
    Text = Text & "  store i32 112, ptr %startup" & vbCrLf
    Text = Text & "  %flags = getelementptr i8, ptr %startup, i64 60" & vbCrLf
    Text = Text & "  %stdin = getelementptr i8, ptr %startup, i64 80" & vbCrLf
    Text = Text & "  %stdout = getelementptr i8, ptr %startup, i64 88" & vbCrLf
    Text = Text & "  %stderr = getelementptr i8, ptr %startup, i64 96" & vbCrLf
    Text = Text & "  %list = getelementptr i8, ptr %startup, i64 104" & vbCrLf
    Text = Text & "  store i32 257, ptr %flags" & vbCrLf
    Text = Text & "  store ptr %input.handle, ptr %stdin" & vbCrLf
    Text = Text & "  store ptr %private.log, ptr %stdout" & vbCrLf
    Text = Text & "  store ptr %private.log, ptr %stderr" & vbCrLf
    Text = Text & "  store ptr %attributes, ptr %list" & vbCrLf
    Text = Text & "  %created = call i1 @ube.target.process.create(ptr %wide.app, ptr %wide.command, ptr %wide.directory, ptr %startup, ptr %information)" & vbCrLf
    Text = Text & "  br i1 %created, label %created.owned, label %io.fail" & vbCrLf
    Text = Text & "created.owned:" & vbCrLf
    Text = Text & "  %native.process = load ptr, ptr %information" & vbCrLf
    Text = Text & "  %native.thread.ptr = getelementptr i8, ptr %information, i64 8" & vbCrLf
    Text = Text & "  %native.thread = load ptr, ptr %native.thread.ptr" & vbCrLf
    Text = Text & "  store ptr %native.process, ptr %process.ptr" & vbCrLf
    Text = Text & "  store ptr %native.thread, ptr %thread.ptr" & vbCrLf
    Text = Text & "  %assigned = call i1 @ube.target.process.assign(ptr %job, ptr %native.process)" & vbCrLf
    Text = Text & "  br i1 %assigned, label %contained, label %io.fail" & vbCrLf
    Text = Text & "contained:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %attached.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %resumed = call i1 @ube.target.process.resume(ptr %native.thread)" & vbCrLf
    Text = Text & "  br i1 %resumed, label %started, label %io.fail" & vbCrLf
    Text = Text & "started:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %started.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.target.process.deleteattributes(ptr %attributes)" & vbCrLf
    Text = Text & "  store i1 false, ptr %attribute.live" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  br label %retain.failure" & vbCrLf
    Text = Text & "retain.failure:" & vbCrLf
    Text = Text & "  %live = load i1, ptr %attribute.live" & vbCrLf
    Text = Text & "  br i1 %live, label %delete.attributes, label %unlock" & vbCrLf
    Text = Text & "delete.attributes:" & vbCrLf
    Text = Text & "  call void @ube.target.process.deleteattributes(ptr %attributes)" & vbCrLf
    Text = Text & "  br label %unlock" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "invalid.private:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  br label %request.fail" & vbCrLf
    Text = Text & "exhausted.private:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  br label %memory.fail" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.process.start(ptr %ctx, ptr %app, ptr %command, ptr %directory, i64 %log.token, ptr %token.out, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.app = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %descriptor.command = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %descriptor.directory = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %app, ptr %token.out)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %app, ptr %failure)" & vbCrLf
    Text = Text & "  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %command, ptr %token.out)" & vbCrLf
    Text = Text & "  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %command, ptr %failure)" & vbCrLf
    Text = Text & "  %alias.4 = call i1 @ube.array.descriptor.overlaps(ptr %directory, ptr %token.out)" & vbCrLf
    Text = Text & "  %alias.5 = call i1 @ube.array.descriptor.overlaps(ptr %directory, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  %aliases.2 = or i1 %aliases.1, %alias.2" & vbCrLf
    Text = Text & "  %aliases.3 = or i1 %aliases.2, %alias.3" & vbCrLf
    Text = Text & "  %aliases.4 = or i1 %aliases.3, %alias.4" & vbCrLf
    Text = Text & "  %aliases.5 = or i1 %aliases.4, %alias.5" & vbCrLf
    Text = Text & "  br i1 %aliases.5, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.app = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %app)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.app, ptr %descriptor.app" & vbCrLf
    Text = Text & "  %pin.app = extractvalue { i64, i64, ptr, ptr } %snapshot.app, 3" & vbCrLf
    Text = Text & "  %snapshot.command = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %command)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.command, ptr %descriptor.command" & vbCrLf
    Text = Text & "  %pin.command = extractvalue { i64, i64, ptr, ptr } %snapshot.command, 3" & vbCrLf
    Text = Text & "  %same.command.app = icmp eq ptr %command, %app" & vbCrLf
    Text = Text & "  %selected.command.app = select i1 %same.command.app, ptr %descriptor.app, ptr %descriptor.command" & vbCrLf
    Text = Text & "  %snapshot.directory = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %directory)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.directory, ptr %descriptor.directory" & vbCrLf
    Text = Text & "  %pin.directory = extractvalue { i64, i64, ptr, ptr } %snapshot.directory, 3" & vbCrLf
    Text = Text & "  %same.directory.app = icmp eq ptr %directory, %app" & vbCrLf
    Text = Text & "  %selected.directory.app = select i1 %same.directory.app, ptr %descriptor.app, ptr %descriptor.directory" & vbCrLf
    Text = Text & "  %same.directory.command = icmp eq ptr %directory, %command" & vbCrLf
    Text = Text & "  %selected.directory.command = select i1 %same.directory.command, ptr %selected.command.app, ptr %selected.directory.app" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.process.start.pinned(ptr %ctx, ptr %descriptor.app, ptr %selected.command.app, ptr %selected.directory.command, i64 %log.token, ptr %token.out, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.app)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.command)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.directory)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeProcessStart = Text
End Function

' Emits the reviewed NativeProcessWait target definitions.
Private Function NativeProcessWait() As String
    Dim Text As String
    Text = Text & "define internal i1 @ube.process.wait(ptr %ctx, i64 %token, i64 %milliseconds, ptr %state.out, ptr %exit.out, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %same.a = icmp eq ptr %state.out, %exit.out" & vbCrLf
    Text = Text & "  %same.b = icmp eq ptr %state.out, %failure" & vbCrLf
    Text = Text & "  %same.c = icmp eq ptr %exit.out, %failure" & vbCrLf
    Text = Text & "  %null.a = icmp eq ptr %state.out, null" & vbCrLf
    Text = Text & "  %null.b = icmp eq ptr %exit.out, null" & vbCrLf
    Text = Text & "  %null.c = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %same.ab = or i1 %same.a, %same.b" & vbCrLf
    Text = Text & "  %same = or i1 %same.ab, %same.c" & vbCrLf
    Text = Text & "  %null.ab = or i1 %null.a, %null.b" & vbCrLf
    Text = Text & "  %nulls = or i1 %null.ab, %null.c" & vbCrLf
    Text = Text & "  %bad = or i1 %same, %nulls" & vbCrLf
    Text = Text & "  br i1 %bad, label %alias.fail, label %validate" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "validate:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %excessive = icmp ugt i64 %milliseconds, 5000" & vbCrLf
    Text = Text & "  br i1 %excessive, label %request.fail, label %lookup" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %observe" & vbCrLf
    Text = Text & "observe:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.process.state(ptr %slot)" & vbCrLf
    Text = Text & "  %timeout = trunc i64 %milliseconds to i32" & vbCrLf
    Text = Text & "  %observation = call i32 @ube.process.observe(ptr %state, i32 %timeout)" & vbCrLf
    Text = Text & "  %bad.observation = icmp slt i32 %observation, 0" & vbCrLf
    Text = Text & "  br i1 %bad.observation, label %io.fail, label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %value = zext i32 %observation to i64" & vbCrLf
    Text = Text & "  store atomic i64 %value, ptr %state.out monotonic, align 8" & vbCrLf
    Text = Text & "  %finished = icmp eq i32 %observation, 1" & vbCrLf
    Text = Text & "  br i1 %finished, label %publish.exit, label %success" & vbCrLf
    Text = Text & "publish.exit:" & vbCrLf
    Text = Text & "  %exit.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 5" & vbCrLf
    Text = Text & "  %code = load atomic i64, ptr %exit.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %code, ptr %exit.out monotonic, align 8" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.process.terminate(ptr %ctx, i64 %token, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %null = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  br i1 %null, label %alias.fail, label %lookup" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %inspect" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.process.state(ptr %slot)" & vbCrLf
    Text = Text & "  %observation = call i32 @ube.process.observe(ptr %state, i32 0)" & vbCrLf
    Text = Text & "  %complete = icmp eq i32 %observation, 1" & vbCrLf
    Text = Text & "  br i1 %complete, label %success, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %attached = load atomic i64, ptr %attached.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %contained = icmp ne i64 %attached, 0" & vbCrLf
    Text = Text & "  br i1 %contained, label %job, label %process" & vbCrLf
    Text = Text & "job:" & vbCrLf
    Text = Text & "  %job.handle = load ptr, ptr %state" & vbCrLf
    Text = Text & "  %job.stopped = call i1 @ube.target.process.terminatejob(ptr %job.handle)" & vbCrLf
    Text = Text & "  br i1 %job.stopped, label %success, label %io.fail" & vbCrLf
    Text = Text & "process:" & vbCrLf
    Text = Text & "  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  %process.handle = load ptr, ptr %process.ptr" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %process.handle, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %stop, label %success" & vbCrLf
    Text = Text & "stop:" & vbCrLf
    Text = Text & "  %stopped = call i1 @ube.target.process.terminate(ptr %process.handle)" & vbCrLf
    Text = Text & "  br i1 %stopped, label %success, label %io.fail" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeProcessWait = Text
End Function

' Emits the reviewed NativeProcessRelease target definitions.
Private Function NativeProcessRelease() As String
    Dim Text As String
    Text = Text & "define internal i1 @ube.process.close(ptr %ctx, ptr %token.out, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %token.out, %failure" & vbCrLf
    Text = Text & "  %null.token = icmp eq ptr %token.out, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %nulls = or i1 %null.token, %null.failure" & vbCrLf
    Text = Text & "  %bad = or i1 %same, %nulls" & vbCrLf
    Text = Text & "  br i1 %bad, label %alias.fail, label %lookup" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %success, label %acquire" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %observe" & vbCrLf
    Text = Text & "observe:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.process.state(ptr %slot)" & vbCrLf
    Text = Text & "  %observation = call i32 @ube.process.observe(ptr %state, i32 0)" & vbCrLf
    Text = Text & "  %bad.observation = icmp slt i32 %observation, 0" & vbCrLf
    Text = Text & "  br i1 %bad.observation, label %io.fail, label %ready" & vbCrLf
    Text = Text & "ready:" & vbCrLf
    Text = Text & "  %complete = icmp eq i32 %observation, 1" & vbCrLf
    Text = Text & "  br i1 %complete, label %release, label %busy" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  br label %handles" & vbCrLf
    Text = Text & "handles:" & vbCrLf
    Text = Text & "  %index = phi i64 [0, %release], [%next, %advance]" & vbCrLf
    Text = Text & "  %all = phi i1 [true, %release], [%accepted, %advance]" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr ptr, ptr %state, i64 %index" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %handle, null" & vbCrLf
    Text = Text & "  br i1 %present, label %close, label %advance" & vbCrLf
    Text = Text & "close:" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.target.process.close(ptr %handle)" & vbCrLf
    Text = Text & "  br i1 %closed, label %clear, label %advance" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  store ptr null, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %is.job = icmp eq i64 %index, 0" & vbCrLf
    Text = Text & "  br i1 %is.job, label %detach, label %advance" & vbCrLf
    Text = Text & "detach:" & vbCrLf
    Text = Text & "  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %attached.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  br label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %current = phi i1 [true, %handles], [false, %close], [true, %clear], [true, %detach]" & vbCrLf
    Text = Text & "  %accepted = and i1 %all, %current" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, 5" & vbCrLf
    Text = Text & "  br i1 %more, label %handles, label %finish" & vbCrLf
    Text = Text & "finish:" & vbCrLf
    Text = Text & "  br i1 %accepted, label %forget, label %close.fail" & vbCrLf
    Text = Text & "forget:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "busy:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %busy.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 12, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "close.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    NativeProcessRelease = Text
End Function

