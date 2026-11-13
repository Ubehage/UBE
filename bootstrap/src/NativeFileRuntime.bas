Attribute VB_Name = "NativeFileRuntime"
Option Explicit

' Emits counted Windows file operations with explicit tokens and bounded packed-byte scratch.

' Returns fixed support definitions for the emitter's bounded IR output pipeline.
Public Function NativeFileIR() As String
    NativeFileIR = NativeFileIR & FileTargetsAndRegistryIR()
    NativeFileIR = NativeFileIR & FileAcquisitionIR()
    NativeFileIR = NativeFileIR & FileTransferAndReleaseIR()
    NativeFileIR = NativeFileIR & SystemOperationsIR()
    NativeFileIR = NativeFileIR & PathOperationsIR()
    NativeFileIR = NativeFileIR & FileMetadataIR()
    NativeFileIR = NativeFileIR & SystemIntrospectionIR()
    NativeFileIR = NativeFileIR & NamespaceOperationsIR()
End Function

' Defines isolated OS entry points and atomic token registry admission.
Private Function FileTargetsAndRegistryIR() As String
    Dim Text As String
    Text = Text & "@ube.resource.next = internal global i64 1, align 8" & vbCrLf
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
    Text = Text & "  %access = select i1 %write, i32 1073741952, i32 -2147483648" & vbCrLf
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
    Text = Text & "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0" & vbCrLf
    Text = Text & "  store atomic i64 %number, ptr %err monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %code, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.aliasfail(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %err monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i64 @ube.resource.token() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %attempt" & vbCrLf
    Text = Text & "attempt:" & vbCrLf
    Text = Text & "  %old = load atomic i64, ptr @ube.resource.next acquire, align 8" & vbCrLf
    Text = Text & "  %exhausted = icmp ugt i64 %old, 2147483647" & vbCrLf
    Text = Text & "  br i1 %exhausted, label %failed, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %old, 1" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr @ube.resource.next, i64 %old, i64 %next acq_rel acquire" & vbCrLf
    Text = Text & "  %won = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %done, label %attempt" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i64 %old" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i64 0" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.resource.reserve(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %claim, label %advance" & vbCrLf
    Text = Text & "claim:" & vbCrLf
    Text = Text & "  %busy = getelementptr %ube.resource, ptr %slot, i32 0, i32 4" & vbCrLf
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
    Text = Text & "define internal void @ube.resource.unlock(ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %busy = getelementptr %ube.resource, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %busy release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.resource.empty(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %busy.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 4" & vbCrLf
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
    Text = Text & "define internal ptr @ube.resource.acquire(ptr %ctx, i64 %wanted, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %positive = icmp sgt i64 %wanted, 0" & vbCrLf
    Text = Text & "  br i1 %positive, label %scan, label %stale" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %matches = icmp eq i64 %token, %wanted" & vbCrLf
    Text = Text & "  br i1 %matches, label %claim, label %advance" & vbCrLf
    Text = Text & "claim:" & vbCrLf
    Text = Text & "  %busy.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 4" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr %busy.ptr, i64 0, i64 1 acq_rel acquire" & vbCrLf
    Text = Text & "  %won = extractvalue { i64, i1 } %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %check, label %busy" & vbCrLf
    Text = Text & "check:" & vbCrLf
    Text = Text & "  %again = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %again, %wanted" & vbCrLf
    Text = Text & "  br i1 %same, label %done, label %unlock" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
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
    Text = Text & "define internal void @ube.resource.forget(ptr %ctx, ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %block.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  %block = load ptr, ptr %block.ptr" & vbCrLf
    Text = Text & "  store ptr null, ptr %block.ptr" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr null, ptr %handle.ptr" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
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
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
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
    Text = Text & "define internal i1 @ube.file.open.pinned(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %mode = select i1 %write, i64 2, i64 1" & vbCrLf
    Text = Text & "  %result = call i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i64 %mode)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.open(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %token.out)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %length.out)" & vbCrLf
    Text = Text & "  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  %aliases.2 = or i1 %aliases.1, %alias.2" & vbCrLf
    Text = Text & "  br i1 %aliases.2, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path" & vbCrLf
    Text = Text & "  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.file.open.pinned(ptr %ctx, ptr %descriptor.path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.path)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i64 %mode) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %write = icmp eq i64 %mode, 2" & vbCrLf
    Text = Text & "  %directory = icmp eq i64 %mode, 3" & vbCrLf
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
    Text = Text & "  store atomic i64 0, ptr %length.out monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %old.token = load atomic i64, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  %owned = icmp ne i64 %old.token, 0" & vbCrLf
    Text = Text & "  %negative = icmp slt i64 %maximum, 0" & vbCrLf
    Text = Text & "  %bad.request = or i1 %owned, %negative" & vbCrLf
    Text = Text & "  br i1 %bad.request, label %request.fail, label %path.size" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "path.size:" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %path monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %path, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
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
    Text = Text & "  %byte = load atomic i64, ptr %cell monotonic, align 8" & vbCrLf
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
    Text = Text & "  %slot = call ptr @ube.resource.reserve(ptr %ctx)" & vbCrLf
    Text = Text & "  %no.slot = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %no.slot, label %allocation.fail, label %identity" & vbCrLf
    Text = Text & "identity:" & vbCrLf
    Text = Text & "  %token = call i64 @ube.resource.token()" & vbCrLf
    Text = Text & "  %exhausted = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %exhausted, label %unreserve, label %allocate" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %unreserve, label %pack.start" & vbCrLf
    Text = Text & "unreserve:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  br label %allocation.fail" & vbCrLf
    Text = Text & "allocation.fail:" & vbCrLf
    Text = Text & "  %allocation.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 8, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pack.start:" & vbCrLf
    Text = Text & "  %block.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  store ptr %block, ptr %block.ptr" & vbCrLf
    Text = Text & "  %packed = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide = getelementptr i8, ptr %packed, i64 4096" & vbCrLf
    Text = Text & "  br label %pack" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %pack.index = phi i64 [ 0, %pack.start ], [ %pack.next, %pack ]" & vbCrLf
    Text = Text & "  %pack.source = getelementptr i64, ptr %data, i64 %pack.index" & vbCrLf
    Text = Text & "  %pack.value = load atomic i64, ptr %pack.source monotonic, align 8" & vbCrLf
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
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  br label %path.fail" & vbCrLf
    Text = Text & "open:" & vbCrLf
    Text = Text & "  %terminator = getelementptr i16, ptr %wide, i32 %wide.length" & vbCrLf
    Text = Text & "  store i16 0, ptr %terminator" & vbCrLf
    Text = Text & "  br i1 %directory, label %open.directory, label %open.file" & vbCrLf
    Text = Text & "open.directory:" & vbCrLf
    Text = Text & "  %directory.handle = call ptr @ube.target.directory.open(ptr %wide)" & vbCrLf
    Text = Text & "  br label %opened" & vbCrLf
    Text = Text & "open.file:" & vbCrLf
    Text = Text & "  %file.handle = call ptr @ube.target.file.open(ptr %wide, i1 %write)" & vbCrLf
    Text = Text & "  br label %opened" & vbCrLf
    Text = Text & "opened:" & vbCrLf
    Text = Text & "  %handle = phi ptr [ %directory.handle, %open.directory ], [ %file.handle, %open.file ]" & vbCrLf
    Text = Text & "  %invalid.handle = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)" & vbCrLf
    Text = Text & "  %null.handle = icmp eq ptr %handle, null" & vbCrLf
    Text = Text & "  %bad.handle = or i1 %invalid.handle, %null.handle" & vbCrLf
    Text = Text & "  br i1 %bad.handle, label %open.fail, label %admit" & vbCrLf
    Text = Text & "open.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  %open.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "admit:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr %handle, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  store atomic i64 %mode, ptr %mode.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %kind = call i32 @ube.target.file.type(ptr %handle)" & vbCrLf
    Text = Text & "  %regular = icmp eq i32 %kind, 1" & vbCrLf
    Text = Text & "  br i1 %regular, label %mode.check, label %query.fail" & vbCrLf
    Text = Text & "mode.check:" & vbCrLf
    Text = Text & "  br i1 %directory, label %directory.check, label %file.check" & vbCrLf
    Text = Text & "directory.check:" & vbCrLf
    Text = Text & "  %is.directory = call i1 @ube.target.directory.check(ptr %handle)" & vbCrLf
    Text = Text & "  br i1 %is.directory, label %success.create, label %query.fail" & vbCrLf
    Text = Text & "file.check:" & vbCrLf
    Text = Text & "  br i1 %write, label %success.create, label %query" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %size.out monotonic, align 8" & vbCrLf
    Text = Text & "  %queried = call i1 @ube.target.file.size(ptr %handle, ptr %size.out)" & vbCrLf
    Text = Text & "  br i1 %queried, label %size.check, label %query.fail" & vbCrLf
    Text = Text & "size.check:" & vbCrLf
    Text = Text & "  %size = load atomic i64, ptr %size.out monotonic, align 8" & vbCrLf
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
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  %reject.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %failure.code, i64 %error.number)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "retained:" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "success.create:" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success.read:" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  %result.length = phi i64 [ 0, %success.create ], [ %size, %success.read ]" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %token, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %result.length, ptr %length.out monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    FileAcquisitionIR = Text
End Function

' Defines single-operation byte transfers and explicit file release.
Private Function FileTransferAndReleaseIR() As String
    Dim Text As String
    Text = Text & "define internal i1 @ube.file.transfer.pinned(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {" & vbCrLf
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
    Text = Text & "  store atomic i64 0, ptr %progress monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
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
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %mode" & vbCrLf
    Text = Text & "mode:" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %actual.mode = load atomic i64, ptr %mode.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %wanted.mode = select i1 %write, i64 2, i64 1" & vbCrLf
    Text = Text & "  %right.mode = icmp eq i64 %actual.mode, %wanted.mode" & vbCrLf
    Text = Text & "  br i1 %right.mode, label %check.empty, label %mode.fail" & vbCrLf
    Text = Text & "mode.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "check.empty:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %count, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %empty.success, label %prepare" & vbCrLf
    Text = Text & "empty.success:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  %payload = getelementptr i64, ptr %data, i64 %start" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr i64, ptr %array, i64 3" & vbCrLf
    Text = Text & "  %owner = load ptr, ptr %owner.ptr" & vbCrLf
    Text = Text & "  call void @ube.block.retain(ptr %owner)" & vbCrLf
    Text = Text & "  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2" & vbCrLf
    Text = Text & "  %scratch.block = load ptr, ptr %scratch.ptr" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %scratch.block, i64 1" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %count32 = trunc i64 %count to i32" & vbCrLf
    Text = Text & "  store i32 0, ptr %native.progress" & vbCrLf
    Text = Text & "  br i1 %write, label %pack, label %read" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]" & vbCrLf
    Text = Text & "  %source = getelementptr i64, ptr %payload, i64 %index" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %source monotonic, align 8" & vbCrLf
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
    Text = Text & "  store atomic i64 %done, ptr %progress monotonic, align 8" & vbCrLf
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
    Text = Text & "  store atomic volatile i64 %read.value, ptr %read.target monotonic, align 8" & vbCrLf
    Text = Text & "  %read.next = add i64 %read.index, 1" & vbCrLf
    Text = Text & "  %read.more = icmp ult i64 %read.next, %done" & vbCrLf
    Text = Text & "  br i1 %read.more, label %unpack, label %read.complete" & vbCrLf
    Text = Text & "read.complete:" & vbCrLf
    Text = Text & "  store atomic i64 %done, ptr %progress monotonic, align 8" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %owner)" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %owner)" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %code = select i1 %write, i64 15, i64 5" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.transfer(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %progress)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array" & vbCrLf
    Text = Text & "  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.file.transfer.pinned(ptr %ctx, i64 %token, ptr %descriptor.array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.array)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
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
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %token = load atomic i64, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %token, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %success, label %lookup" & vbCrLf
    Text = Text & "lookup:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %kind.low = icmp sge i64 %kind.value, 1" & vbCrLf
    Text = Text & "  %kind.high = icmp sle i64 %kind.value, 3" & vbCrLf
    Text = Text & "  %file.kind = and i1 %kind.low, %kind.high" & vbCrLf
    Text = Text & "  br i1 %file.kind, label %close, label %kind.fail" & vbCrLf
    Text = Text & "kind.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "close:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %closed = call i1 @ube.target.file.close(ptr %handle)" & vbCrLf
    Text = Text & "  br i1 %closed, label %released, label %close.fail" & vbCrLf
    Text = Text & "released:" & vbCrLf
    Text = Text & "  call void @ube.resource.forget(ptr %ctx, ptr %slot)" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %token.out monotonic, align 8" & vbCrLf
    Text = Text & "  br label %success" & vbCrLf
    Text = Text & "close.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
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
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %mode" & vbCrLf
    Text = Text & "mode:" & vbCrLf
    Text = Text & "  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %actual.mode = load atomic i64, ptr %mode.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %writable = icmp eq i64 %actual.mode, 2" & vbCrLf
    Text = Text & "  br i1 %writable, label %flush, label %mode.fail" & vbCrLf
    Text = Text & "mode.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "flush:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %ok = call i1 @ube.target.file.flush(ptr %handle)" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
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

' Supplies bounded raw command-line input and standard streams without compiler policy.
Private Function SystemOperationsIR() As String
    Dim Text As String
    Text = Text & "declare dllimport ptr @GetCommandLineW()" & vbCrLf
    Text = Text & "declare dllimport ptr @GetStdHandle(i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)" & vbCrLf
    Text = Text & "define ptr @ube.target.system.commandline() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call ptr @GetCommandLineW()" & vbCrLf
    Text = Text & "  ret ptr %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define ptr @ube.target.system.standard(i32 %which) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call ptr @GetStdHandle(i32 %which)" & vbCrLf
    Text = Text & "  ret ptr %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %bytes, i32 %capacity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide, i32 %units, ptr %bytes, i32 %capacity, ptr null, ptr null)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %count, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %count, %failure" & vbCrLf
    Text = Text & "  %null.count = icmp eq ptr %count, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %overlap.count = call i1 @ube.file.overlaps(ptr %array, ptr %count)" & vbCrLf
    Text = Text & "  %overlap.failure = call i1 @ube.file.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %null = or i1 %null.count, %null.failure" & vbCrLf
    Text = Text & "  %overlap = or i1 %overlap.count, %overlap.failure" & vbCrLf
    Text = Text & "  %bad.scalar = or i1 %alias, %null" & vbCrLf
    Text = Text & "  %bad = or i1 %bad.scalar, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad, label %failed, label %done" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  %status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.commandline.pinned(ptr %ctx, ptr %array, ptr %count, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %count, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %acquire, label %failed" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %wide = call ptr @ube.target.system.commandline()" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %wide, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %io.fail, label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %acquire ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %unit.ptr = getelementptr i16, ptr %wide, i64 %index" & vbCrLf
    Text = Text & "  %unit = load i16, ptr %unit.ptr" & vbCrLf
    Text = Text & "  %end = icmp eq i16 %unit, 0" & vbCrLf
    Text = Text & "  br i1 %end, label %length, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %bounded = icmp ult i64 %next, 32767" & vbCrLf
    Text = Text & "  br i1 %bounded, label %scan, label %request.fail" & vbCrLf
    Text = Text & "length:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %index, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %empty.success, label %measure" & vbCrLf
    Text = Text & "empty.success:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %count monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "measure:" & vbCrLf
    Text = Text & "  %units = trunc i64 %index to i32" & vbCrLf
    Text = Text & "  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)" & vbCrLf
    Text = Text & "  %size = sext i32 %size32 to i64" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %capacity = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %invalid = icmp sle i64 %size, 0" & vbCrLf
    Text = Text & "  %large = icmp sgt i64 %size, 131072" & vbCrLf
    Text = Text & "  %short = icmp sgt i64 %size, %capacity" & vbCrLf
    Text = Text & "  %bad.bound = or i1 %large, %short" & vbCrLf
    Text = Text & "  %bad = or i1 %invalid, %bad.bound" & vbCrLf
    Text = Text & "  br i1 %bad, label %request.fail, label %allocate" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 16384, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %memory.fail, label %convert" & vbCrLf
    Text = Text & "convert:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %scratch, i32 131072)" & vbCrLf
    Text = Text & "  %complete = icmp eq i32 %converted, %size32" & vbCrLf
    Text = Text & "  br i1 %complete, label %prepare, label %conversion.fail" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %copy" & vbCrLf
    Text = Text & "copy:" & vbCrLf
    Text = Text & "  %position = phi i64 [ 0, %prepare ], [ %after, %copy ]" & vbCrLf
    Text = Text & "  %source = getelementptr i8, ptr %scratch, i64 %position" & vbCrLf
    Text = Text & "  %byte = load i8, ptr %source" & vbCrLf
    Text = Text & "  %value = zext i8 %byte to i64" & vbCrLf
    Text = Text & "  %destination = getelementptr i64, ptr %data, i64 %position" & vbCrLf
    Text = Text & "  store atomic volatile i64 %value, ptr %destination monotonic, align 8" & vbCrLf
    Text = Text & "  %after = add i64 %position, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %after, %size" & vbCrLf
    Text = Text & "  br i1 %more, label %copy, label %success" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  store atomic i64 %size, ptr %count monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "conversion.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  br label %io.fail" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.commandline(ptr %ctx, ptr %array, ptr %count, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %count)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array" & vbCrLf
    Text = Text & "  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.system.commandline.pinned(ptr %ctx, ptr %descriptor.array, ptr %count, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.array)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.write.pinned(ptr %ctx, i64 %stream, ptr %array, i64 %start, i64 %count, ptr %written, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %progress = alloca i32, align 4" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %written, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %validate, label %failed" & vbCrLf
    Text = Text & "validate:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %written monotonic, align 8" & vbCrLf
    Text = Text & "  %stdout = icmp eq i64 %stream, 1" & vbCrLf
    Text = Text & "  %stderr = icmp eq i64 %stream, 2" & vbCrLf
    Text = Text & "  %stream.ok = or i1 %stdout, %stderr" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %start.bad = icmp ult i64 %length, %start" & vbCrLf
    Text = Text & "  %count.bad = icmp ugt i64 %count, 65536" & vbCrLf
    Text = Text & "  %bad.range = or i1 %start.bad, %count.bad" & vbCrLf
    Text = Text & "  %range.ok = xor i1 %bad.range, true" & vbCrLf
    Text = Text & "  %request.ok = and i1 %stream.ok, %range.ok" & vbCrLf
    Text = Text & "  br i1 %request.ok, label %range, label %request.fail" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  %remaining = sub i64 %length, %start" & vbCrLf
    Text = Text & "  %past.end = icmp ugt i64 %count, %remaining" & vbCrLf
    Text = Text & "  br i1 %past.end, label %request.fail, label %handle" & vbCrLf
    Text = Text & "handle:" & vbCrLf
    Text = Text & "  %which = select i1 %stdout, i32 -11, i32 -12" & vbCrLf
    Text = Text & "  %native.handle = call ptr @ube.target.system.standard(i32 %which)" & vbCrLf
    Text = Text & "  %null = icmp eq ptr %native.handle, null" & vbCrLf
    Text = Text & "  %invalid = icmp eq ptr %native.handle, inttoptr (i64 -1 to ptr)" & vbCrLf
    Text = Text & "  %bad.handle = or i1 %null, %invalid" & vbCrLf
    Text = Text & "  br i1 %bad.handle, label %io.fail, label %empty.check" & vbCrLf
    Text = Text & "empty.check:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %count, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %empty.success, label %allocate" & vbCrLf
    Text = Text & "empty.success:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %memory.fail, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  %source.base = getelementptr i64, ptr %data, i64 %start" & vbCrLf
    Text = Text & "  br label %pack" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]" & vbCrLf
    Text = Text & "  %source = getelementptr i64, ptr %source.base, i64 %index" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %source monotonic, align 8" & vbCrLf
    Text = Text & "  %byte = trunc i64 %value to i8" & vbCrLf
    Text = Text & "  %destination = getelementptr i8, ptr %scratch, i64 %index" & vbCrLf
    Text = Text & "  store volatile i8 %byte, ptr %destination" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %count" & vbCrLf
    Text = Text & "  br i1 %more, label %pack, label %write" & vbCrLf
    Text = Text & "write:" & vbCrLf
    Text = Text & "  store i32 0, ptr %progress" & vbCrLf
    Text = Text & "  %count32 = trunc i64 %count to i32" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.target.file.write(ptr %native.handle, ptr %scratch, i32 %count32, ptr %progress)" & vbCrLf
    Text = Text & "  %done32 = load i32, ptr %progress" & vbCrLf
    Text = Text & "  %done = zext i32 %done32 to i64" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %bad.progress = icmp ugt i64 %done, %count" & vbCrLf
    Text = Text & "  br i1 %bad.progress, label %io.fail, label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store atomic i64 %done, ptr %written monotonic, align 8" & vbCrLf
    Text = Text & "  br i1 %accepted, label %success, label %io.fail" & vbCrLf
    Text = Text & "success:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 15, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.write(ptr %ctx, i64 %stream, ptr %array, i64 %start, i64 %count, ptr %written, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %written)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array" & vbCrLf
    Text = Text & "  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.system.write.pinned(ptr %ctx, i64 %stream, ptr %descriptor.array, i64 %start, i64 %count, ptr %written, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.array)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    SystemOperationsIR = Text
End Function

' Shares bounded path packing, strict conversion and atomic publication across target operations.
Private Function PathOperationsIR() As String
    Dim Text As String
    Text = Text & "declare dllimport i32 @GetFullPathNameW(ptr, i32, ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @GetFinalPathNameByHandleW(ptr, ptr, i32, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)" & vbCrLf
    Text = Text & "define i32 @ube.target.path.full(ptr %input, ptr %output, i32 %capacity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @GetFullPathNameW(ptr %input, i32 %capacity, ptr %output, ptr null)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.path.final(ptr %handle, ptr %output, i32 %capacity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr %output, i32 %capacity, i32 0)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i32 @ube.target.path.compare(ptr %first, i32 %first.length, ptr %second, i32 %second.length) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i32 @CompareStringOrdinal(ptr %first, i32 %first.length, ptr %second, i32 %second.length, i32 1)" & vbCrLf
    Text = Text & "  ret i32 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %second, ptr %value, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %value, %failure" & vbCrLf
    Text = Text & "  %null.value = icmp eq ptr %value, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %first.value = call i1 @ube.file.overlaps(ptr %first, ptr %value)" & vbCrLf
    Text = Text & "  %first.failure = call i1 @ube.file.overlaps(ptr %first, ptr %failure)" & vbCrLf
    Text = Text & "  %second.value = call i1 @ube.file.overlaps(ptr %second, ptr %value)" & vbCrLf
    Text = Text & "  %second.failure = call i1 @ube.file.overlaps(ptr %second, ptr %failure)" & vbCrLf
    Text = Text & "  %null = or i1 %null.value, %null.failure" & vbCrLf
    Text = Text & "  %first.overlap = or i1 %first.value, %first.failure" & vbCrLf
    Text = Text & "  %second.overlap = or i1 %second.value, %second.failure" & vbCrLf
    Text = Text & "  %overlap = or i1 %first.overlap, %second.overlap" & vbCrLf
    Text = Text & "  %bad.scalar = or i1 %alias, %null" & vbCrLf
    Text = Text & "  %bad = or i1 %bad.scalar, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad, label %failed, label %done" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  %status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i32 @ube.path.decode(ptr %array, ptr %packed, ptr %wide) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %large = icmp ugt i64 %length, 4096" & vbCrLf
    Text = Text & "  br i1 %large, label %failed, label %empty.check" & vbCrLf
    Text = Text & "empty.check:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %length, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %empty.done, label %prepare" & vbCrLf
    Text = Text & "empty.done:" & vbCrLf
    Text = Text & "  store i16 0, ptr %wide" & vbCrLf
    Text = Text & "  ret i32 0" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %pack" & vbCrLf
    Text = Text & "pack:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %prepare ], [ %next, %copy ]" & vbCrLf
    Text = Text & "  %source = getelementptr i64, ptr %data, i64 %index" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %source monotonic, align 8" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %failed, label %copy" & vbCrLf
    Text = Text & "copy:" & vbCrLf
    Text = Text & "  %byte = trunc i64 %value to i8" & vbCrLf
    Text = Text & "  %destination = getelementptr i8, ptr %packed, i64 %index" & vbCrLf
    Text = Text & "  store volatile i8 %byte, ptr %destination" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %length" & vbCrLf
    Text = Text & "  br i1 %more, label %pack, label %convert" & vbCrLf
    Text = Text & "convert:" & vbCrLf
    Text = Text & "  %bytes = trunc i64 %length to i32" & vbCrLf
    Text = Text & "  %units = call i32 @ube.target.file.utf8(ptr %packed, i32 %bytes, ptr %wide, i32 4096)" & vbCrLf
    Text = Text & "  %valid = icmp sgt i32 %units, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %done, label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %units64 = zext i32 %units to i64" & vbCrLf
    Text = Text & "  %terminator = getelementptr i16, ptr %wide, i64 %units64" & vbCrLf
    Text = Text & "  store i16 0, ptr %terminator" & vbCrLf
    Text = Text & "  ret i32 %units" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i32 -1" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.publish(ptr %ctx, ptr %wide, i32 %units, ptr %array, ptr %count, ptr %failure, ptr %packed) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)" & vbCrLf
    Text = Text & "  %size = sext i32 %size32 to i64" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %capacity = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %invalid = icmp sle i64 %size, 0" & vbCrLf
    Text = Text & "  %large = icmp sgt i64 %size, 4096" & vbCrLf
    Text = Text & "  %short = icmp sgt i64 %size, %capacity" & vbCrLf
    Text = Text & "  %bad.bound = or i1 %large, %short" & vbCrLf
    Text = Text & "  %bad = or i1 %invalid, %bad.bound" & vbCrLf
    Text = Text & "  br i1 %bad, label %request.fail, label %convert" & vbCrLf
    Text = Text & "convert:" & vbCrLf
    Text = Text & "  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %packed, i32 4096)" & vbCrLf
    Text = Text & "  %complete = icmp eq i32 %converted, %size32" & vbCrLf
    Text = Text & "  br i1 %complete, label %prepare, label %io.fail" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %copy" & vbCrLf
    Text = Text & "copy:" & vbCrLf
    Text = Text & "  %position = phi i64 [ 0, %prepare ], [ %after, %copy ]" & vbCrLf
    Text = Text & "  %source = getelementptr i8, ptr %packed, i64 %position" & vbCrLf
    Text = Text & "  %byte = load i8, ptr %source" & vbCrLf
    Text = Text & "  %value = zext i8 %byte to i64" & vbCrLf
    Text = Text & "  %destination = getelementptr i64, ptr %data, i64 %position" & vbCrLf
    Text = Text & "  store atomic volatile i64 %value, ptr %destination monotonic, align 8" & vbCrLf
    Text = Text & "  %after = add i64 %position, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %after, %size" & vbCrLf
    Text = Text & "  br i1 %more, label %copy, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  store atomic i64 %size, ptr %count monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %owned = icmp ne ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %owned, label %unlock, label %done" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.resolve.pinned(ptr %ctx, ptr %input, i64 %token, ptr %output, ptr %count, ptr %failure, i1 %final) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %first = select i1 %final, ptr %output, ptr %input" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %output, ptr %count, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %choose, label %failed" & vbCrLf
    Text = Text & "choose:" & vbCrLf
    Text = Text & "  br i1 %final, label %acquire, label %allocate" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %acquired = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %acquired, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %acquired, i32 0, i32 3" & vbCrLf
    Text = Text & "  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %kind.low = icmp sge i64 %kind.value, 1" & vbCrLf
    Text = Text & "  %kind.high = icmp sle i64 %kind.value, 3" & vbCrLf
    Text = Text & "  %file.kind = and i1 %kind.low, %kind.high" & vbCrLf
    Text = Text & "  br i1 %file.kind, label %allocate, label %kind.fail" & vbCrLf
    Text = Text & "kind.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %acquired)" & vbCrLf
    Text = Text & "  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %slot = phi ptr [ null, %choose ], [ %acquired, %kind ]" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %memory.fail, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide.input = getelementptr i8, ptr %scratch, i64 4096" & vbCrLf
    Text = Text & "  %wide.output = getelementptr i8, ptr %scratch, i64 20480" & vbCrLf
    Text = Text & "  %packed.output = getelementptr i8, ptr %scratch, i64 32768" & vbCrLf
    Text = Text & "  br i1 %final, label %physical, label %decode" & vbCrLf
    Text = Text & "physical:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %physical.length = call i32 @ube.target.path.final(ptr %handle, ptr %wide.output, i32 4097)" & vbCrLf
    Text = Text & "  br label %length" & vbCrLf
    Text = Text & "decode:" & vbCrLf
    Text = Text & "  %input.length = call i32 @ube.path.decode(ptr %input, ptr %scratch, ptr %wide.input)" & vbCrLf
    Text = Text & "  %input.valid = icmp sgt i32 %input.length, 0" & vbCrLf
    Text = Text & "  br i1 %input.valid, label %full, label %request.fail" & vbCrLf
    Text = Text & "full:" & vbCrLf
    Text = Text & "  %full.length = call i32 @ube.target.path.full(ptr %wide.input, ptr %wide.output, i32 4097)" & vbCrLf
    Text = Text & "  br label %length" & vbCrLf
    Text = Text & "length:" & vbCrLf
    Text = Text & "  %units = phi i32 [ %physical.length, %physical ], [ %full.length, %full ]" & vbCrLf
    Text = Text & "  %missing.length = icmp eq i32 %units, 0" & vbCrLf
    Text = Text & "  br i1 %missing.length, label %io.fail, label %bound" & vbCrLf
    Text = Text & "bound:" & vbCrLf
    Text = Text & "  %excessive = icmp ugt i32 %units, 4096" & vbCrLf
    Text = Text & "  br i1 %excessive, label %request.fail, label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.publish(ptr %ctx, ptr %wide.output, i32 %units, ptr %output, ptr %count, ptr %failure, ptr %packed.output)" & vbCrLf
    Text = Text & "  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.resolve(ptr %ctx, ptr %input, i64 %token, ptr %output, ptr %count, ptr %failure, i1 %final) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.input = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %descriptor.output = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %input, ptr %count)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %input, ptr %failure)" & vbCrLf
    Text = Text & "  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %count)" & vbCrLf
    Text = Text & "  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  %aliases.2 = or i1 %aliases.1, %alias.2" & vbCrLf
    Text = Text & "  %aliases.3 = or i1 %aliases.2, %alias.3" & vbCrLf
    Text = Text & "  br i1 %aliases.3, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.input = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %input)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.input, ptr %descriptor.input" & vbCrLf
    Text = Text & "  %pin.input = extractvalue { i64, i64, ptr, ptr } %snapshot.input, 3" & vbCrLf
    Text = Text & "  %snapshot.output = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %output)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.output, ptr %descriptor.output" & vbCrLf
    Text = Text & "  %pin.output = extractvalue { i64, i64, ptr, ptr } %snapshot.output, 3" & vbCrLf
    Text = Text & "  %same.output.input = icmp eq ptr %output, %input" & vbCrLf
    Text = Text & "  %selected.output.input = select i1 %same.output.input, ptr %descriptor.input, ptr %descriptor.output" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.path.resolve.pinned(ptr %ctx, ptr %descriptor.input, i64 %token, ptr %selected.output.input, ptr %count, ptr %failure, i1 %final)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.input)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.output)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.compare.pinned(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %allocate, label %failed" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)" & vbCrLf
    Text = Text & "  %no.memory = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %no.memory, label %memory.fail, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide.first = getelementptr i8, ptr %scratch, i64 4096" & vbCrLf
    Text = Text & "  %packed.second = getelementptr i8, ptr %scratch, i64 16384" & vbCrLf
    Text = Text & "  %wide.second = getelementptr i8, ptr %scratch, i64 20480" & vbCrLf
    Text = Text & "  %first.length = call i32 @ube.path.decode(ptr %first, ptr %scratch, ptr %wide.first)" & vbCrLf
    Text = Text & "  %first.invalid = icmp slt i32 %first.length, 0" & vbCrLf
    Text = Text & "  br i1 %first.invalid, label %request.fail, label %second.decode" & vbCrLf
    Text = Text & "second.decode:" & vbCrLf
    Text = Text & "  %second.length = call i32 @ube.path.decode(ptr %second, ptr %packed.second, ptr %wide.second)" & vbCrLf
    Text = Text & "  %second.invalid = icmp slt i32 %second.length, 0" & vbCrLf
    Text = Text & "  br i1 %second.invalid, label %request.fail, label %empty.check" & vbCrLf
    Text = Text & "empty.check:" & vbCrLf
    Text = Text & "  %first.empty = icmp eq i32 %first.length, 0" & vbCrLf
    Text = Text & "  %second.empty = icmp eq i32 %second.length, 0" & vbCrLf
    Text = Text & "  %any.empty = or i1 %first.empty, %second.empty" & vbCrLf
    Text = Text & "  br i1 %any.empty, label %empty, label %compare" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  %same = icmp eq i32 %first.length, %second.length" & vbCrLf
    Text = Text & "  %different = select i1 %first.empty, i64 -1, i64 1" & vbCrLf
    Text = Text & "  %empty.value = select i1 %same, i64 0, i64 %different" & vbCrLf
    Text = Text & "  br label %publish" & vbCrLf
    Text = Text & "compare:" & vbCrLf
    Text = Text & "  %comparison = call i32 @ube.target.path.compare(ptr %wide.first, i32 %first.length, ptr %wide.second, i32 %second.length)" & vbCrLf
    Text = Text & "  %too.low = icmp slt i32 %comparison, 1" & vbCrLf
    Text = Text & "  %too.high = icmp sgt i32 %comparison, 3" & vbCrLf
    Text = Text & "  %invalid = or i1 %too.low, %too.high" & vbCrLf
    Text = Text & "  br i1 %invalid, label %io.fail, label %normalize" & vbCrLf
    Text = Text & "normalize:" & vbCrLf
    Text = Text & "  %normalized = sub i32 %comparison, 2" & vbCrLf
    Text = Text & "  %value = sext i32 %normalized to i64" & vbCrLf
    Text = Text & "  br label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %result = phi i64 [ %empty.value, %empty ], [ %value, %normalize ]" & vbCrLf
    Text = Text & "  store atomic i64 %result, ptr %ordering monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.compare(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.first = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %descriptor.second = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %ordering)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %failure)" & vbCrLf
    Text = Text & "  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %ordering)" & vbCrLf
    Text = Text & "  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  %aliases.2 = or i1 %aliases.1, %alias.2" & vbCrLf
    Text = Text & "  %aliases.3 = or i1 %aliases.2, %alias.3" & vbCrLf
    Text = Text & "  br i1 %aliases.3, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.first = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %first)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.first, ptr %descriptor.first" & vbCrLf
    Text = Text & "  %pin.first = extractvalue { i64, i64, ptr, ptr } %snapshot.first, 3" & vbCrLf
    Text = Text & "  %snapshot.second = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %second)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.second, ptr %descriptor.second" & vbCrLf
    Text = Text & "  %pin.second = extractvalue { i64, i64, ptr, ptr } %snapshot.second, 3" & vbCrLf
    Text = Text & "  %same.second.first = icmp eq ptr %second, %first" & vbCrLf
    Text = Text & "  %selected.second.first = select i1 %same.second.first, ptr %descriptor.first, ptr %descriptor.second" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.path.compare.pinned(ptr %ctx, ptr %descriptor.first, ptr %selected.second.first, ptr %ordering, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.first)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.second)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    PathOperationsIR = Text
End Function

' Supplies bounded target metadata operations with explicit owner and publication rules.
Private Function FileMetadataIR() As String
    Dim Text As String
    Text = Text & "declare dllimport i32 @GetFileInformationByHandle(ptr, ptr)" & vbCrLf
    Text = Text & "define ptr @ube.target.directory.open(ptr %path) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %handle = call ptr @CreateFileW(ptr %path, i32 128, i32 7, ptr null, i32 3, i32 33554432, ptr null)" & vbCrLf
    Text = Text & "  ret ptr %handle" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.target.file.info(ptr %handle, ptr %information) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = call i32 @GetFileInformationByHandle(ptr %handle, ptr %information)" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %status, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.target.directory.check(ptr %handle) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %information = alloca [52 x i8], align 4" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.target.file.info(ptr %handle, ptr %information)" & vbCrLf
    Text = Text & "  br i1 %accepted, label %inspect, label %failed" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %attributes = load i32, ptr %information" & vbCrLf
    Text = Text & "  %directory = and i32 %attributes, 16" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %directory, 0" & vbCrLf
    Text = Text & "  ret i1 %ok" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.directory.open.pinned(ptr %ctx, ptr %path, ptr %token, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %length = alloca i64, align 8" & vbCrLf
    Text = Text & "  %result = call i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 0, ptr %token, ptr %length, ptr %failure, i64 3)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.directory.open(ptr %ctx, ptr %path, ptr %token, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %token)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path" & vbCrLf
    Text = Text & "  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.directory.open.pinned(ptr %ctx, ptr %descriptor.path, ptr %token, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.path)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.identity.pinned(ptr %ctx, i64 %token, ptr %array, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %information = alloca [52 x i8], align 4" & vbCrLf
    Text = Text & "  %null = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %overlap = call i1 @ube.file.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  %bad.output = or i1 %null, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %capacity" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "capacity:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %lower = load atomic i64, ptr %array monotonic, align 8" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %distance = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %distance, 1" & vbCrLf
    Text = Text & "  %short = icmp slt i64 %length, 12" & vbCrLf
    Text = Text & "  br i1 %short, label %request.fail, label %acquire" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %kind.low = icmp sge i64 %kind.value, 1" & vbCrLf
    Text = Text & "  %kind.high = icmp sle i64 %kind.value, 3" & vbCrLf
    Text = Text & "  %right.kind = and i1 %kind.low, %kind.high" & vbCrLf
    Text = Text & "  br i1 %right.kind, label %query, label %kind.fail" & vbCrLf
    Text = Text & "kind.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.target.file.info(ptr %handle, ptr %information)" & vbCrLf
    Text = Text & "  br i1 %accepted, label %prepare, label %io.fail" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr" & vbCrLf
    Text = Text & "  br label %copy" & vbCrLf
    Text = Text & "copy:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %prepare ], [ %next, %copy ]" & vbCrLf
    Text = Text & "  %volume = icmp ult i64 %index, 4" & vbCrLf
    Text = Text & "  %base = select i1 %volume, i64 28, i64 40" & vbCrLf
    Text = Text & "  %offset = add i64 %base, %index" & vbCrLf
    Text = Text & "  %source = getelementptr i8, ptr %information, i64 %offset" & vbCrLf
    Text = Text & "  %byte = load i8, ptr %source" & vbCrLf
    Text = Text & "  %value = zext i8 %byte to i64" & vbCrLf
    Text = Text & "  %destination = getelementptr i64, ptr %data, i64 %index" & vbCrLf
    Text = Text & "  store atomic volatile i64 %value, ptr %destination monotonic, align 8" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, 12" & vbCrLf
    Text = Text & "  br i1 %more, label %copy, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.identity(ptr %ctx, i64 %token, ptr %array, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %alias.0, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array" & vbCrLf
    Text = Text & "  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.file.identity.pinned(ptr %ctx, i64 %token, ptr %descriptor.array, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.array)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.length(ptr %ctx, i64 %token, ptr %length, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %size = alloca i64, align 8" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %length, %failure" & vbCrLf
    Text = Text & "  %null.length = icmp eq ptr %length, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %null = or i1 %null.length, %null.failure" & vbCrLf
    Text = Text & "  %bad.output = or i1 %alias, %null" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %acquire" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %slot, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %failed, label %kind" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3" & vbCrLf
    Text = Text & "  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %kind.low = icmp sge i64 %kind.value, 1" & vbCrLf
    Text = Text & "  %kind.high = icmp sle i64 %kind.value, 2" & vbCrLf
    Text = Text & "  %right.kind = and i1 %kind.low, %kind.high" & vbCrLf
    Text = Text & "  br i1 %right.kind, label %query, label %kind.fail" & vbCrLf
    Text = Text & "kind.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1" & vbCrLf
    Text = Text & "  %handle = load ptr, ptr %handle.ptr" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %size monotonic, align 8" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.target.file.size(ptr %handle, ptr %size)" & vbCrLf
    Text = Text & "  br i1 %accepted, label %range, label %io.fail" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  %value = load atomic i64, ptr %size monotonic, align 8" & vbCrLf
    Text = Text & "  %invalid = icmp ugt i64 %value, 2147483647" & vbCrLf
    Text = Text & "  br i1 %invalid, label %range.fail, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  store atomic i64 %value, ptr %length monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "range.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %range.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 4, i64 6)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.resource.unlock(ptr %slot)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    FileMetadataIR = Text
End Function

' Supplies bounded target metadata operations with explicit owner and publication rules.
Private Function SystemIntrospectionIR() As String
    Dim Text As String
    Text = Text & "declare dllimport i32 @GetModuleFileNameW(ptr, ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport i64 @GetTickCount64()" & vbCrLf
    Text = Text & "define i32 @ube.target.system.executable(ptr %output, i32 %capacity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %length = call i32 @GetModuleFileNameW(ptr null, ptr %output, i32 %capacity)" & vbCrLf
    Text = Text & "  ret i32 %length" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.system.clock() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %value = call i64 @GetTickCount64()" & vbCrLf
    Text = Text & "  ret i64 %value" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.executable.pinned(ptr %ctx, ptr %output, ptr %count, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %output, ptr %count, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %allocate, label %failed" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %memory.fail, label %query" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide = getelementptr i8, ptr %scratch, i64 20480" & vbCrLf
    Text = Text & "  %packed = getelementptr i8, ptr %scratch, i64 32768" & vbCrLf
    Text = Text & "  %units = call i32 @ube.target.system.executable(ptr %wide, i32 4097)" & vbCrLf
    Text = Text & "  %empty = icmp eq i32 %units, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %io.fail, label %range" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  %large = icmp ugt i32 %units, 4096" & vbCrLf
    Text = Text & "  br i1 %large, label %request.fail, label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.publish(ptr %ctx, ptr %wide, i32 %units, ptr %output, ptr %count, ptr %failure, ptr %packed)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.executable(ptr %ctx, ptr %output, ptr %count, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.output = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %count)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.output = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %output)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.output, ptr %descriptor.output" & vbCrLf
    Text = Text & "  %pin.output = extractvalue { i64, i64, ptr, ptr } %snapshot.output, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.system.executable.pinned(ptr %ctx, ptr %descriptor.output, ptr %count, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.output)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.system.clock(ptr %ctx, ptr %value, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %alias = icmp eq ptr %value, %failure" & vbCrLf
    Text = Text & "  %null.value = icmp eq ptr %value, null" & vbCrLf
    Text = Text & "  %null.failure = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %null = or i1 %null.value, %null.failure" & vbCrLf
    Text = Text & "  %bad.output = or i1 %alias, %null" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %query" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %ticks = call i64 @ube.target.system.clock()" & vbCrLf
    Text = Text & "  store atomic i64 %ticks, ptr %value monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    SystemIntrospectionIR = Text
End Function

' Supplies individual namespace mutations and explicit existence observations without compiler policy.
Private Function NamespaceOperationsIR() As String
    Dim Text As String
    Text = Text & "declare dllimport i32 @GetLastError()" & vbCrLf
    Text = Text & "declare dllimport i32 @CreateDirectoryW(ptr, ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @RemoveDirectoryW(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @DeleteFileW(ptr)" & vbCrLf
    Text = Text & "declare dllimport i32 @MoveFileExW(ptr, ptr, i32)" & vbCrLf
    Text = Text & "declare dllimport i32 @GetFileAttributesW(ptr)" & vbCrLf
    Text = Text & "define internal i64 @ube.target.path.error(i32 %accepted) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %ok = icmp ne i32 %accepted, 0" & vbCrLf
    Text = Text & "  br i1 %ok, label %done, label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i64 0" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  %error32 = call i32 @GetLastError()" & vbCrLf
    Text = Text & "  %error = zext i32 %error32 to i64" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %error, 0" & vbCrLf
    Text = Text & "  %result = select i1 %empty, i64 1, i64 %error" & vbCrLf
    Text = Text & "  ret i64 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.directory.create(ptr %path) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %accepted = call i32 @CreateDirectoryW(ptr %path, ptr null)" & vbCrLf
    Text = Text & "  %error = call i64 @ube.target.path.error(i32 %accepted)" & vbCrLf
    Text = Text & "  ret i64 %error" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.directory.remove(ptr %path) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %accepted = call i32 @RemoveDirectoryW(ptr %path)" & vbCrLf
    Text = Text & "  %error = call i64 @ube.target.path.error(i32 %accepted)" & vbCrLf
    Text = Text & "  ret i64 %error" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.file.delete(ptr %path) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %accepted = call i32 @DeleteFileW(ptr %path)" & vbCrLf
    Text = Text & "  %error = call i64 @ube.target.path.error(i32 %accepted)" & vbCrLf
    Text = Text & "  ret i64 %error" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.file.replace(ptr %source, ptr %destination) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %accepted = call i32 @MoveFileExW(ptr %source, ptr %destination, i32 9)" & vbCrLf
    Text = Text & "  %error = call i64 @ube.target.path.error(i32 %accepted)" & vbCrLf
    Text = Text & "  ret i64 %error" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.target.path.attributes(ptr %path) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %attributes = call i32 @GetFileAttributesW(ptr %path)" & vbCrLf
    Text = Text & "  %invalid = icmp eq i32 %attributes, -1" & vbCrLf
    Text = Text & "  br i1 %invalid, label %failed, label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %value = zext i32 %attributes to i64" & vbCrLf
    Text = Text & "  ret i64 %value" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  %error = call i64 @ube.target.path.error(i32 0)" & vbCrLf
    Text = Text & "  %negative = sub i64 0, %error" & vbCrLf
    Text = Text & "  ret i64 %negative" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.mutate.pinned(ptr %ctx, ptr %first, ptr %second, ptr %failure, i64 %operation) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %replace = icmp eq i64 %operation, 4" & vbCrLf
    Text = Text & "  %other = select i1 %replace, ptr %second, ptr %first" & vbCrLf
    Text = Text & "  %null = icmp eq ptr %failure, null" & vbCrLf
    Text = Text & "  %first.overlap = call i1 @ube.file.overlaps(ptr %first, ptr %failure)" & vbCrLf
    Text = Text & "  %second.overlap = call i1 @ube.file.overlaps(ptr %other, ptr %failure)" & vbCrLf
    Text = Text & "  %overlap = or i1 %first.overlap, %second.overlap" & vbCrLf
    Text = Text & "  %bad.output = or i1 %null, %overlap" & vbCrLf
    Text = Text & "  br i1 %bad.output, label %alias.fail, label %allocate" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %failure monotonic, align 8" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %memory.fail, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide.first = getelementptr i8, ptr %scratch, i64 4096" & vbCrLf
    Text = Text & "  %packed.second = getelementptr i8, ptr %scratch, i64 16384" & vbCrLf
    Text = Text & "  %wide.second = getelementptr i8, ptr %scratch, i64 20480" & vbCrLf
    Text = Text & "  %first.length = call i32 @ube.path.decode(ptr %first, ptr %scratch, ptr %wide.first)" & vbCrLf
    Text = Text & "  %first.valid = icmp sgt i32 %first.length, 0" & vbCrLf
    Text = Text & "  br i1 %first.valid, label %select, label %request.fail" & vbCrLf
    Text = Text & "select:" & vbCrLf
    Text = Text & "  br i1 %replace, label %second.decode, label %create.check" & vbCrLf
    Text = Text & "second.decode:" & vbCrLf
    Text = Text & "  %second.length = call i32 @ube.path.decode(ptr %second, ptr %packed.second, ptr %wide.second)" & vbCrLf
    Text = Text & "  %second.valid = icmp sgt i32 %second.length, 0" & vbCrLf
    Text = Text & "  br i1 %second.valid, label %move, label %request.fail" & vbCrLf
    Text = Text & "move:" & vbCrLf
    Text = Text & "  %move.error = call i64 @ube.target.file.replace(ptr %wide.first, ptr %wide.second)" & vbCrLf
    Text = Text & "  br label %result" & vbCrLf
    Text = Text & "create.check:" & vbCrLf
    Text = Text & "  %create = icmp eq i64 %operation, 1" & vbCrLf
    Text = Text & "  br i1 %create, label %create.directory, label %remove.check" & vbCrLf
    Text = Text & "create.directory:" & vbCrLf
    Text = Text & "  %create.error = call i64 @ube.target.directory.create(ptr %wide.first)" & vbCrLf
    Text = Text & "  br label %result" & vbCrLf
    Text = Text & "remove.check:" & vbCrLf
    Text = Text & "  %directory = icmp eq i64 %operation, 2" & vbCrLf
    Text = Text & "  br i1 %directory, label %remove.directory, label %delete.file" & vbCrLf
    Text = Text & "remove.directory:" & vbCrLf
    Text = Text & "  %remove.error = call i64 @ube.target.directory.remove(ptr %wide.first)" & vbCrLf
    Text = Text & "  br label %result" & vbCrLf
    Text = Text & "delete.file:" & vbCrLf
    Text = Text & "  %delete.error = call i64 @ube.target.file.delete(ptr %wide.first)" & vbCrLf
    Text = Text & "  br label %result" & vbCrLf
    Text = Text & "result:" & vbCrLf
    Text = Text & "  %error = phi i64 [ %move.error, %move ], [ %create.error, %create.directory ], [ %remove.error, %remove.directory ], [ %delete.error, %delete.file ]" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %success = icmp eq i64 %error, 0" & vbCrLf
    Text = Text & "  br i1 %success, label %done, label %classify" & vbCrLf
    Text = Text & "classify:" & vbCrLf
    Text = Text & "  %file.exists = icmp eq i64 %error, 80" & vbCrLf
    Text = Text & "  %directory.exists = icmp eq i64 %error, 183" & vbCrLf
    Text = Text & "  %exists = or i1 %file.exists, %directory.exists" & vbCrLf
    Text = Text & "  %creating = icmp eq i64 %operation, 1" & vbCrLf
    Text = Text & "  %collision = and i1 %exists, %creating" & vbCrLf
    Text = Text & "  %file.missing = icmp eq i64 %error, 2" & vbCrLf
    Text = Text & "  %path.missing = icmp eq i64 %error, 3" & vbCrLf
    Text = Text & "  %absent = or i1 %file.missing, %path.missing" & vbCrLf
    Text = Text & "  %code.absence = select i1 %absent, i64 18, i64 5" & vbCrLf
    Text = Text & "  %number.absence = select i1 %absent, i64 53, i64 57" & vbCrLf
    Text = Text & "  %code = select i1 %collision, i64 17, i64 %code.absence" & vbCrLf
    Text = Text & "  %number = select i1 %collision, i64 58, i64 %number.absence" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 %number)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.mutate(ptr %ctx, ptr %first, ptr %second, ptr %failure, i64 %operation) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.first = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %descriptor.second = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %failure)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.first = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %first)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.first, ptr %descriptor.first" & vbCrLf
    Text = Text & "  %pin.first = extractvalue { i64, i64, ptr, ptr } %snapshot.first, 3" & vbCrLf
    Text = Text & "  %snapshot.second = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %second)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.second, ptr %descriptor.second" & vbCrLf
    Text = Text & "  %pin.second = extractvalue { i64, i64, ptr, ptr } %snapshot.second, 3" & vbCrLf
    Text = Text & "  %same.second.first = icmp eq ptr %second, %first" & vbCrLf
    Text = Text & "  %selected.second.first = select i1 %same.second.first, ptr %descriptor.first, ptr %descriptor.second" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.path.mutate.pinned(ptr %ctx, ptr %descriptor.first, ptr %selected.second.first, ptr %failure, i64 %operation)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.first)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.second)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.directory.create(ptr %ctx, ptr %path, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 1)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.directory.remove(ptr %ctx, ptr %path, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 2)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.delete(ptr %ctx, ptr %path, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 3)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.file.replace(ptr %ctx, ptr %source, ptr %destination, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %source, ptr %destination, ptr %failure, i64 4)" & vbCrLf
    Text = Text & "  ret i1 %result" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.kind.pinned(ptr %ctx, ptr %path, ptr %kind, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %path, ptr %kind, ptr %failure)" & vbCrLf
    Text = Text & "  br i1 %outputs, label %allocate, label %failed" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)" & vbCrLf
    Text = Text & "  %missing = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %missing, label %memory.fail, label %prepare" & vbCrLf
    Text = Text & "prepare:" & vbCrLf
    Text = Text & "  %scratch = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %wide = getelementptr i8, ptr %scratch, i64 4096" & vbCrLf
    Text = Text & "  %length = call i32 @ube.path.decode(ptr %path, ptr %scratch, ptr %wide)" & vbCrLf
    Text = Text & "  %valid = icmp sgt i32 %length, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %query, label %request.fail" & vbCrLf
    Text = Text & "query:" & vbCrLf
    Text = Text & "  %attributes = call i64 @ube.target.path.attributes(ptr %wide)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %negative = icmp slt i64 %attributes, 0" & vbCrLf
    Text = Text & "  br i1 %negative, label %classify, label %present" & vbCrLf
    Text = Text & "classify:" & vbCrLf
    Text = Text & "  %file.missing = icmp eq i64 %attributes, -2" & vbCrLf
    Text = Text & "  %path.missing = icmp eq i64 %attributes, -3" & vbCrLf
    Text = Text & "  %absent = or i1 %file.missing, %path.missing" & vbCrLf
    Text = Text & "  br i1 %absent, label %missing.path, label %io.fail" & vbCrLf
    Text = Text & "missing.path:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %kind monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "present:" & vbCrLf
    Text = Text & "  %directory.bit = and i64 %attributes, 16" & vbCrLf
    Text = Text & "  %directory = icmp ne i64 %directory.bit, 0" & vbCrLf
    Text = Text & "  %value = select i1 %directory, i64 2, i64 1" & vbCrLf
    Text = Text & "  store atomic i64 %value, ptr %kind monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "memory.fail:" & vbCrLf
    Text = Text & "  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "request.fail:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "io.fail:" & vbCrLf
    Text = Text & "  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.path.kind(ptr %ctx, ptr %path, ptr %kind, ptr %failure) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8" & vbCrLf
    Text = Text & "  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %kind)" & vbCrLf
    Text = Text & "  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)" & vbCrLf
    Text = Text & "  %aliases.1 = or i1 %alias.0, %alias.1" & vbCrLf
    Text = Text & "  br i1 %aliases.1, label %alias.fail, label %pin" & vbCrLf
    Text = Text & "alias.fail:" & vbCrLf
    Text = Text & "  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "pin:" & vbCrLf
    Text = Text & "  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)" & vbCrLf
    Text = Text & "  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path" & vbCrLf
    Text = Text & "  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3" & vbCrLf
    Text = Text & "  %accepted = call i1 @ube.path.kind.pinned(ptr %ctx, ptr %descriptor.path, ptr %kind, ptr %failure)" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %pin.path)" & vbCrLf
    Text = Text & "  ret i1 %accepted" & vbCrLf
    Text = Text & "}" & vbCrLf
    NamespaceOperationsIR = Text
End Function
