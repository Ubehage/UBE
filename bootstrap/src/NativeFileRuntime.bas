Attribute VB_Name = "NativeFileRuntime"
Option Explicit

' Emits counted Windows file operations with explicit tokens and bounded packed-byte scratch.

' Returns fixed support definitions for the emitter's bounded IR output pipeline.
Public Function NativeFileIR() As String
    NativeFileIR = NativeFileIR & FileTargetsAndRegistryIR()
    NativeFileIR = NativeFileIR & FileAcquisitionIR()
    NativeFileIR = NativeFileIR & FileTransferAndReleaseIR()
End Function

' Defines isolated OS entry points and atomic token registry admission.
Private Function FileTargetsAndRegistryIR() As String
    Dim Text As String
    Text = Text & "@ube.file.next = internal global i64 1, align 8" & vbCrLf
    Text = Text & "declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @GetFileType(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @GetFileSizeEx(ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @CloseHandle(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @FlushFileBuffers(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)" & vbCrLf
    Text = Text & "define ptr @ube.target.file.open(ptr %path, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %access = select i1 %write, i32 1073741824, i32 -2147483648" & vbCrLf
    Text = Text & "  %creation = select i1 %write, i32 1, i32 3" & vbCrLf
    Text = Text & "  %sharing = select i1 %write, i32 0, i32 7" & vbCrLf
    Text = Text & "  %handle = call ptr @CreateFileW(ptr %path, i32 %access, i32 %sharing, ptr null, i32 %creation, i32 128, ptr null)" & vbCrLf
    Text = Text & "  ret ptr %handle" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.file.type(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %kind = call i32 @GetFileType(ptr %handle)" & vbCrLf
    Text = Text & "  ret i32 %kind" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.size(ptr %handle, ptr %size) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @GetFileSizeEx(ptr %handle, ptr %size)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.read(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @ReadFile(ptr %handle, ptr %bytes, i32 %count, ptr %progress, ptr null)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @WriteFile(ptr %handle, ptr %bytes, i32 %count, ptr %progress, ptr null)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.close(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @CloseHandle(ptr %handle)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.flush(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @FlushFileBuffers(ptr %handle)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.file.utf8(ptr %bytes, i32 %count, ptr %wide, i32 %capacity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %length = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %bytes, i32 %count, ptr %wide, i32 %capacity)" & vbCrLf
    Text = Text & "  ret i32 %length" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 %number) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0" & vbCrLf
    Text = Text & "  store i64 %number, ptr %err" & vbCrLf
    Text = Text & "  store i64 %code, ptr %failure" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.aliasfail(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0" & vbCrLf
    Text = Text & "  store i64 5, ptr %err" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i64 @ube.file.token() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %attempt" & vbCrLf
    Text = Text & "attempt:" & vbCrLf
    Text = Text & "  %old = load atomic i64, ptr @ube.file.next acquire, align 8" & vbCrLf
    Text = Text & "  %exhausted = icmp ugt i64 %old, 2147483647" & vbCrLf
    Text = Text & "  br i1 %exhausted, label %failed, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %old, 1" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr @ube.file.next, i64 %old, i64 %next acq_rel acquire" & vbCrLf
    Text = Text & "  %won = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %done, label %attempt" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i64 %old" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i64 0" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.file.reserve(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %claim, label %advance" & vbCrLf
    Text = Text & "claim:" & vbCrLf
    Text = Text & "  %busy = getelementptr %ube.file, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr %busy, i64 0, i64 1 acq_rel acquire" & vbCrLf
    Text = Text & "  %won = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %check, label %advance" & vbCrLf
    Text = Text & "check:" & vbCrLf
    Text = Text & "  %again = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %still.empty = icmp eq i64 %again, 0" & vbCrLf
    Text = Text & "  br i1 %still.empty, label %done, label %unlock" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %busy release, align 8" & vbCrLf
    Text = Text & "  br label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, 64" & vbCrLf
    Text = Text & "  br i1 %more, label %scan, label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %slot" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.file.unlock(ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %busy = getelementptr %ube.file, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %busy release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.empty(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %busy.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  %busy = load atomic i64, ptr %busy.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %occupied = or i64 %token, %busy" & vbCrLf
    Text = Text & "  %live = icmp ne i64 %occupied, 0" & vbCrLf
    Text = Text & "  br i1 %live, label %failed, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, 64" & vbCrLf
    Text = Text & "  br i1 %more, label %scan, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    FileTargetsAndRegistryIR = Text
End Function

' Defines strict counted path admission and recoverable file acquisition.
Private Function FileAcquisitionIR() As String
    Dim Text As String
    Text = Text & "define internal ptr @ube.file.acquire(ptr %ctx, i64 %wanted, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %positive = icmp sgt i64 %wanted, 0" & vbCrLf
    Text = Text & "  br i1 %positive, label %scan, label %stale" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %matches = icmp eq i64 %token, %wanted" & vbCrLf
    Text = Text & "  br i1 %matches, label %claim, label %advance" & vbCrLf
    Text = Text & "claim:" & vbCrLf
    Text = Text & "  %busy.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr %busy.ptr, i64 0, i64 1 acq_rel acquire" & vbCrLf
    Text = Text & "  %won = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %check, label %busy" & vbCrLf
    Text = Text & "check:" & vbCrLf
    Text = Text & "  %again = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %again, %wanted" & vbCrLf
    Text = Text & "  br i1 %same, label %done, label %unlock" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  br label %stale" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, 64" & vbCrLf
    Text = Text & "  br i1 %more, label %scan, label %stale" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %slot" & vbCrLf
    Text = Text & "busy:" & vbCrLf
    Text = Text & "  %busy.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 13, i64 5)" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "stale:" & vbCrLf
    Text = Text & "  %stale.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.file.forget(ptr %ctx, ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %block.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  %block = load ptr, ptr %block.ptr" & vbCrLf
    Text = Text & "  store ptr null, ptr %block.ptr" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr null, ptr %handle.ptr" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %block)" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %collected = call i1 @ube.memory.collect(ptr %ctx)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.overlaps(ptr %array, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %address = ptrtoint ptr %output to i64" & vbCrLf
    Text = Text & "  %descriptor = ptrtoint ptr %array to i64" & vbCrLf
    Text = Text & "  %desc.after = sub i64 %address, %descriptor" & vbCrLf
    Text = Text & "  %desc.before = sub i64 %descriptor, %address" & vbCrLf
    Text = Text & "  %desc.inside = icmp ult i64 %desc.after, 32" & vbCrLf
    Text = Text & "  %desc.cross = icmp ult i64 %desc.before, 8" & vbCrLf
    Text = Text & "  %desc.overlap = or i1 %desc.inside, %desc.cross" & vbCrLf
    Text = Text & "  %lower = load i64, ptr %array" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load i64, ptr %upper.ptr" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %bytes = mul i64 %length, 8" & vbCrLf
    Text = Text & "  %nonempty = icmp ne i64 %length, 0" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  %payload = ptrtoint ptr %data to i64" & vbCrLf
    Text = Text & "  %data.after = sub i64 %address, %payload" & vbCrLf
    Text = Text & "  %data.before = sub i64 %payload, %address" & vbCrLf
    Text = Text & "  %data.inside = icmp ult i64 %data.after, %bytes" & vbCrLf
    Text = Text & "  %data.cross = icmp ult i64 %data.before, 8" & vbCrLf
    Text = Text & "  %data.overlap = or i1 %data.inside, %data.cross" & vbCrLf
    Text = Text & "  %occupied = and i1 %nonempty, %data.overlap" & vbCrLf
    Text = Text & "  %overlap = or i1 %desc.overlap, %occupied" & vbCrLf
    Text = Text & "  ret i1 %overlap" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.open(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %size.out = alloca i64, align 8" & vbCrLf
    Text = Text & "  %alias.a = icmp eq ptr %token.out, %length.out" & vbCrLf
    Text = Text & "  %alias.b = icmp eq ptr %token.out, %failure" & vbCrLf
    Text = Text & "  %alias.c = icmp eq ptr %length.out, %failure" & vbCrLf
    Text = Text & "  %null.a = icmp eq ptr %token.out, null" & vbCrLf
    Text = Text & "  %null.b = icmp eq ptr %length.out, null" & vbCrLf
    Text = Text & "  %null.c = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %alias.ab = or i1 %alias.a, %alias.b" & vbCrLf
    Text = Text & "  %alias.abc = or i1 %alias.ab, %alias.c" & vbCrLf
    Text = Text & "  %null.ab = or i1 %null.a, %null.b" & vbCrLf
    Text = Text & "  %null.abc = or i1 %null.ab, %null.c" & vbCrLf
    Text = Text & "  %overlap.token = call i1 @ube.file.overlaps(ptr %path, ptr %token.out)" & vbCrLf
    Text = Text & "  %overlap.length = call i1 @ube.file.overlaps(ptr %path, ptr %length.out)" & vbCrLf
    Text = Text & "  %overlap.failure = call i1 @ube.file.overlaps(ptr %path, ptr %failure)" & vbCrLf
    Text = Text & "  %overlap.ab = or i1 %overlap.token, %overlap.length" & vbCrLf
    Text = Text & "  %overlap = or i1 %overlap.ab, %overlap.failure" & vbCrLf
    Text = Text & "  %scalar.alias = or i1 %alias.abc, %null.abc" & vbCrLf
    Text = Text & "  %alias = or i1 %scalar.alias, %overlap" & vbCrLf
    Text = Text & "  br i1 %alias, label %alias.fail, label %outputs" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "outputs:" & vbCrLf
    Text = Text & "  store i64 0, ptr %length.out" & vbCrLf
    Text = Text & "  store i64 0, ptr %failure" & vbCrLf
    Text = Text & "  %old.token = load i64, ptr %token.out" & vbCrLf
    Text = Text & "  %owned = icmp ne i64 %old.token, 0" & vbCrLf
    Text = Text & "  %negative = icmp slt i64 %maximum, 0" & vbCrLf
    Text = Text & "  %bad.request = or i1 %owned, %negative" & vbCrLf
    Text = Text & "  br i1 %bad.request, label %request.fail, label %path.size" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "path.size:" & vbCrLf
    Text = Text & "  %lower = load i64, ptr %path" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %path, i64 1" & vbCrLf
    Text = Text & "  %upper = load i64, ptr %upper.ptr" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %empty = icmp sle i64 %length, 0" & vbCrLf
    Text = Text & "  %long = icmp sgt i64 %length, 4096" & vbCrLf
    Text = Text & "  %bad.path = or i1 %empty, %long" & vbCrLf
    Text = Text & "  br i1 %bad.path, label %path.fail, label %path.data" & vbCrLf
    Text = Text & "path.data:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %path, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %path.data ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %cell = getelementptr i64, ptr %data, i64 %index" & vbCrLf
    Text = Text & "  %byte = load i64, ptr %cell" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %byte, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %path.fail, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %length" & vbCrLf
    Text = Text & "  br i1 %more, label %scan, label %reserve" & vbCrLf
    Text = Text & "path.fail:" & vbCrLf
    Text = Text & "  %path.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 2, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "reserve:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.file.reserve(ptr %ctx)" & vbCrLf
    Text = Text & "  %no.slot = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %no.slot, label %allocation.fail, label %identity" & vbCrLf
    Text = Text & "identity:" & vbCrLf
    Text = Text & "  %token = call i64 @ube.file.token()" & vbCrLf
    Text = Text & "  %exhausted = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %exhausted, label %unreserve, label %allocate" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %unreserve, label %pack.start" & vbCrLf
    Text = Text & "unreserve:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  br label %allocation.fail" & vbCrLf
    Text = Text & "allocation.fail:" & vbCrLf
    Text = Text & "  %allocation.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 8, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pack.start:" & vbCrLf
    Text = Text & "  %block.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  store ptr %block, ptr %block.ptr" & vbCrLf
    Text = Text & "  %packed = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide = getelementptr i8, ptr %packed, i64 4096" & vbCrLf
    Text = Text & "  br label %pack" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %pack.index = phi i64 [ 0, %pack.start ], [ %pack.next, %pack ]" & vbCrLf
    Text = Text & "  %pack.source = getelementptr i64, ptr %data, i64 %pack.index" & vbCrLf
    Text = Text & "  %pack.value = load i64, ptr %pack.source" & vbCrLf
    Text = Text & "  %pack.byte = trunc i64 %pack.value to i8" & vbCrLf
    Text = Text & "  %pack.target = getelementptr i8, ptr %packed, i64 %pack.index" & vbCrLf
    Text = Text & "  store volatile i8 %pack.byte, ptr %pack.target" & vbCrLf
    Text = Text & "  %pack.next = add i64 %pack.index, 1" & vbCrLf
    Text = Text & "  %pack.more = icmp ult i64 %pack.next, %length" & vbCrLf
    Text = Text & "  br i1 %pack.more, label %pack, label %convert" & vbCrLf
    Text = Text & "convert:" & vbCrLf
    Text = Text & "  %length32 = trunc i64 %length to i32" & vbCrLf
    Text = Text & "  %wide.length = call i32 @ube.target.file.utf8(ptr %packed, i32 %length32, ptr %wide, i32 4096)" & vbCrLf
    Text = Text & "  %wide.bad = icmp sle i32 %wide.length, 0" & vbCrLf
    Text = Text & "  %wide.large = icmp sgt i32 %wide.length, 4096" & vbCrLf
    Text = Text & "  %wide.invalid = or i1 %wide.bad, %wide.large" & vbCrLf
    Text = Text & "  br i1 %wide.invalid, label %conversion.fail, label %open" & vbCrLf
    Text = Text & "conversion.fail:" & vbCrLf
    Text = Text & "  call void @ube.file.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  br label %path.fail" & vbCrLf
    Text = Text & "open:" & vbCrLf
    Text = Text & "  %terminator = getelementptr i16, ptr %wide, i32 %wide.length" & vbCrLf
    Text = Text & "  store i16 0, ptr %terminator" & vbCrLf
    Text = Text & "  %handle = call ptr @ube.target.file.open(ptr %wide, i1 %write)" & vbCrLf
    Text = Text & "  %invalid.handle = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)" & vbCrLf
    Text = Text & "  %null.handle = icmp eq ptr %handle, null" & vbCrLf
    Text = Text & "  %bad.handle = or i1 %invalid.handle, %null.handle" & vbCrLf
    Text = Text & "  br i1 %bad.handle, label %open.fail, label %admit" & vbCrLf
    Text = Text & "open.fail:" & vbCrLf
    Text = Text & "  call void @ube.file.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  %open.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "admit:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr %handle, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %mode = select i1 %write, i64 2, i64 1" & vbCrLf
    Text = Text & "  store i64 %mode, ptr %mode.ptr" & vbCrLf
    Text = Text & "  %kind = call i32 @ube.target.file.type(ptr %handle)" & vbCrLf
    Text = Text & "  %regular = icmp eq i32 %kind, 1" & vbCrLf
    Text = Text & "  br i1 %regular, label %mode.check, label %query.fail" & vbCrLf
    Text = Text & "mode.check:" & vbCrLf
    Text = Text & "  br i1 %write, label %success.create, label %query" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  store i64 0, ptr %size.out" & vbCrLf
    Text = Text & "  %queried = call i1 @ube.target.file.size(ptr %handle, ptr %size.out)" & vbCrLf
    Text = Text & "  br i1 %queried, label %size.check, label %query.fail" & vbCrLf
    Text = Text & "size.check:" & vbCrLf
    Text = Text & "  %size = load i64, ptr %size.out" & vbCrLf
    Text = Text & "  %size.negative = icmp slt i64 %size, 0" & vbCrLf
    Text = Text & "  br i1 %size.negative, label %query.fail, label %size.limit" & vbCrLf
    Text = Text & "size.limit:" & vbCrLf
    Text = Text & "  %too.large = icmp sgt i64 %size, %maximum" & vbCrLf
    Text = Text & "  br i1 %too.large, label %limit.fail, label %success.read" & vbCrLf
    Text = Text & "query.fail:" & vbCrLf
    Text = Text & "  br label %reject" & vbCrLf
    Text = Text & "limit.fail:" & vbCrLf
    Text = Text & "  br label %reject" & vbCrLf
    Text = Text & "reject:" & vbCrLf
    Text = Text & "  %failure.code = phi i64 [ 3, %query.fail ], [ 4, %limit.fail ]" & vbCrLf
    Text = Text & "  %error.number = phi i64 [ 57, %query.fail ], [ 6, %limit.fail ]" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.target.file.close(ptr %handle)" & vbCrLf
    Text = Text & "  br i1 %closed, label %rejected, label %retained" & vbCrLf
    Text = Text & "rejected:" & vbCrLf
    Text = Text & "  call void @ube.file.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  %reject.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %failure.code, i64 %error.number)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "retained:" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  store i64 %token, ptr %token.out" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "success.create:" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success.read:" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  %result.length = phi i64 [ 0, %success.create ], [ %size, %success.read ]" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  store i64 %token, ptr %token.out" & vbCrLf
    Text = Text & "  store i64 %result.length, ptr %length.out" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    FileAcquisitionIR = Text
End Function

' Defines single-operation byte transfers and explicit file release.
Private Function FileTransferAndReleaseIR() As String
    Dim Text As String
    Text = Text & "define internal i1 @ube.file.transfer(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %native.progress = alloca i32, align 4" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %progress, %failure" & vbCrLf
    Text = Text & "  %null.progress = icmp eq ptr %progress, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %null.output = or i1 %null.progress, %null.failure" & vbCrLf
    Text = Text & "  %overlap.progress = call i1 @ube.file.overlaps(ptr %array, ptr %progress)" & vbCrLf
    Text = Text & "  %overlap.failure = call i1 @ube.file.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %overlap = or i1 %overlap.progress, %overlap.failure" & vbCrLf
    Text = Text & "  %bad.scalar = or i1 %alias, %null.output" & vbCrLf
    Text = Text & "  %bad.output = or i1 %bad.scalar, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %outputs" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "outputs:" & vbCrLf
    Text = Text & "  store i64 0, ptr %progress" & vbCrLf
    Text = Text & "  store i64 0, ptr %failure" & vbCrLf
    Text = Text & "  %lower = load i64, ptr %array" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load i64, ptr %upper.ptr" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %start.negative = icmp slt i64 %start, 0" & vbCrLf
    Text = Text & "  %count.negative = icmp slt i64 %count, 0" & vbCrLf
    Text = Text & "  %count.large = icmp sgt i64 %count, 65536" & vbCrLf
    Text = Text & "  %start.past = icmp sgt i64 %start, %length" & vbCrLf
    Text = Text & "  %negative = or i1 %start.negative, %count.negative" & vbCrLf
    Text = Text & "  %past = or i1 %count.large, %start.past" & vbCrLf
    Text = Text & "  %invalid = or i1 %negative, %past" & vbCrLf
    Text = Text & "  br i1 %invalid, label %request.fail, label %range" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  %remaining = sub i64 %length, %start" & vbCrLf
    Text = Text & "  %past.end = icmp sgt i64 %count, %remaining" & vbCrLf
    Text = Text & "  br i1 %past.end, label %request.fail, label %lookup" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %mode" & vbCrLf
    Text = Text & "mode:" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %actual.mode = load i64, ptr %mode.ptr" & vbCrLf
    Text = Text & "  %wanted.mode = select i1 %write, i64 2, i64 1" & vbCrLf
    Text = Text & "  %right.mode = icmp eq i64 %actual.mode, %wanted.mode" & vbCrLf
    Text = Text & "  br i1 %right.mode, label %check.empty, label %mode.fail" & vbCrLf
    Text = Text & "mode.fail:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "check.empty:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %count, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %empty.success, label %prepare" & vbCrLf
    Text = Text & "empty.success:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  %payload = getelementptr i64, ptr %data, i64 %start" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr i64, ptr %array, i64 3" & vbCrLf
    Text = Text & "  %owner = load ptr, ptr %owner.ptr" & vbCrLf
    Text = Text & "  call void @ube.block.retain(ptr %owner)" & vbCrLf
    Text = Text & "  %scratch.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  %scratch.block = load ptr, ptr %scratch.ptr" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %scratch.block, i64 1" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %count32 = trunc i64 %count to i32" & vbCrLf
    Text = Text & "  store i32 0, ptr %native.progress" & vbCrLf
    Text = Text & "  br i1 %write, label %pack, label %read" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]" & vbCrLf
    Text = Text & "  %source = getelementptr i64, ptr %payload, i64 %index" & vbCrLf
    Text = Text & "  %value = load i64, ptr %source" & vbCrLf
    Text = Text & "  %byte = trunc i64 %value to i8" & vbCrLf
    Text = Text & "  %target = getelementptr i8, ptr %scratch, i64 %index" & vbCrLf
    Text = Text & "  store volatile i8 %byte, ptr %target" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %count" & vbCrLf
    Text = Text & "  br i1 %more, label %pack, label %native.write" & vbCrLf
    Text = Text & "native.write:" & vbCrLf
    Text = Text & "  %write.ok = call i1 @ube.target.file.write(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)" & vbCrLf
    Text = Text & "  br label %observed" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %read.ok = call i1 @ube.target.file.read(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)" & vbCrLf
    Text = Text & "  br label %observed" & vbCrLf
    Text = Text & "observed:" & vbCrLf
    Text = Text & "  %ok = phi i1 [ %write.ok, %native.write ], [ %read.ok, %read ]" & vbCrLf
    Text = Text & "  %done32 = load i32, ptr %native.progress" & vbCrLf
    Text = Text & "  %done = zext i32 %done32 to i64" & vbCrLf
    Text = Text & "  %bad.progress = icmp ugt i64 %done, %count" & vbCrLf
    Text = Text & "  br i1 %bad.progress, label %io.fail, label %publish.mode" & vbCrLf
    Text = Text & "publish.mode:" & vbCrLf
    Text = Text & "  br i1 %write, label %write.progress, label %read.status" & vbCrLf
    Text = Text & "write.progress:" & vbCrLf
    Text = Text & "  store i64 %done, ptr %progress" & vbCrLf
    Text = Text & "  br i1 %ok, label %success, label %io.fail" & vbCrLf
    Text = Text & "read.status:" & vbCrLf
    Text = Text & "  br i1 %ok, label %read.progress, label %io.fail" & vbCrLf
    Text = Text & "read.progress:" & vbCrLf
    Text = Text & "  %has.bytes = icmp ne i64 %done, 0" & vbCrLf
    Text = Text & "  br i1 %has.bytes, label %unpack, label %read.complete" & vbCrLf
    Text = Text & "unpack:" & vbCrLf
    Text = Text & "  %read.index = phi i64 [ 0, %read.progress ], [ %read.next, %unpack ]" & vbCrLf
    Text = Text & "  %read.source = getelementptr i8, ptr %scratch, i64 %read.index" & vbCrLf
    Text = Text & "  %read.byte = load i8, ptr %read.source" & vbCrLf
    Text = Text & "  %read.value = zext i8 %read.byte to i64" & vbCrLf
    Text = Text & "  %read.target = getelementptr i64, ptr %payload, i64 %read.index" & vbCrLf
    Text = Text & "  store volatile i64 %read.value, ptr %read.target" & vbCrLf
    Text = Text & "  %read.next = add i64 %read.index, 1" & vbCrLf
    Text = Text & "  %read.more = icmp ult i64 %read.next, %done" & vbCrLf
    Text = Text & "  br i1 %read.more, label %unpack, label %read.complete" & vbCrLf
    Text = Text & "read.complete:" & vbCrLf
    Text = Text & "  store i64 %done, ptr %progress" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %owner)" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %owner)" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %code = select i1 %write, i64 15, i64 5" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.close(ptr %ctx, ptr %token.out, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %token.out, %failure" & vbCrLf
    Text = Text & "  %null.token = icmp eq ptr %token.out, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %null.output = or i1 %null.token, %null.failure" & vbCrLf
    Text = Text & "  %bad.output = or i1 %alias, %null.output" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %outputs" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "outputs:" & vbCrLf
    Text = Text & "  store i64 0, ptr %failure" & vbCrLf
    Text = Text & "  %token = load i64, ptr %token.out" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %success, label %lookup" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %close" & vbCrLf
    Text = Text & "close:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.target.file.close(ptr %handle)" & vbCrLf
    Text = Text & "  br i1 %closed, label %released, label %close.fail" & vbCrLf
    Text = Text & "released:" & vbCrLf
    Text = Text & "  call void @ube.file.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  store i64 0, ptr %token.out" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "close.fail:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.flush(ptr %ctx, i64 %token, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %null.output = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  br i1 %null.output, label %alias.fail, label %lookup" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  store i64 0, ptr %failure" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %mode" & vbCrLf
    Text = Text & "mode:" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %actual.mode = load i64, ptr %mode.ptr" & vbCrLf
    Text = Text & "  %writable = icmp eq i64 %actual.mode, 2" & vbCrLf
    Text = Text & "  br i1 %writable, label %flush, label %mode.fail" & vbCrLf
    Text = Text & "mode.fail:" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "flush:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %ok = call i1 @ube.target.file.flush(ptr %handle)" & vbCrLf
    Text = Text & "  call void @ube.file.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  br i1 %ok, label %success, label %flush.fail" & vbCrLf
    Text = Text & "flush.fail:" & vbCrLf
    Text = Text & "  %flush.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 16, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    FileTransferAndReleaseIR = Text
End Function
