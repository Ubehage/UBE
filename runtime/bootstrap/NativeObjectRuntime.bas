Attribute VB_Name = "NativeObjectRuntime"
Option Explicit
' Emits genuine object storage and irreducible monitor atomics; wait policy stays in UBECore.
Public Function NativeObjectIR() As String
    NativeObjectIR = NativeObjectIR & ObjectIdentityIR()
    NativeObjectIR = NativeObjectIR & ObjectMonitorIR()
End Function

Private Function ObjectIdentityIR() As String
    Dim Text As String
    Text = Text & "; Genuine class identities share precise managed allocation metadata, never value-record identities." & vbCrLf
    Text = Text & "define internal ptr @ube.object.find(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %nothing, label %read.state" & vbCrLf
    Text = Text & "read.state:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %installed = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %installed, label %find, label %bad" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read.kind, label %bad" & vbCrLf
    Text = Text & "read.kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  %kind = load i64, ptr %kind.ptr, align 8" & vbCrLf
    Text = Text & "  %object = icmp eq i64 %kind, 3" & vbCrLf
    Text = Text & "  br i1 %object, label %size, label %bad" & vbCrLf
    Text = Text & "size:" & vbCrLf
    Text = Text & "  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %bytes = load i64, ptr %bytes.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp uge i64 %bytes, 24" & vbCrLf
    Text = Text & "  br i1 %valid, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "nothing:" & vbCrLf
    Text = Text & "  store atomic i64 91, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Header: immutable class descriptor, atomic owning thread context, owner-only recursion." & vbCrLf
    Text = Text & "define i1 @ube.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %identity.slot = alloca i64, align 8" & vbCrLf
    Text = Text & "  %descriptor.valid = icmp ne ptr %descriptor, null" & vbCrLf
    Text = Text & "  %output.valid = icmp ne ptr %output, null" & vbCrLf
    Text = Text & "  %size.valid = icmp ule i64 %bytes, 9223372036854775783" & vbCrLf
    Text = Text & "  %pointers.valid = and i1 %descriptor.valid, %output.valid" & vbCrLf
    Text = Text & "  %valid = and i1 %pointers.valid, %size.valid" & vbCrLf
    Text = Text & "  br i1 %valid, label %allocate, label %bad" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %total = add i64 %bytes, 24" & vbCrLf
    Text = Text & "  %allocated = call i1 @ube.managed.create(ptr %ctx, i64 %total, i64 0, i64 3, ptr %identity.slot)" & vbCrLf
    Text = Text & "  br i1 %allocated, label %initialize, label %failed" & vbCrLf
    Text = Text & "initialize:" & vbCrLf
    Text = Text & "  %identity = load i64, ptr %identity.slot, align 8" & vbCrLf
    Text = Text & "  ; A rejected candidate stays frame-owned for ordinary cleanup; output is untouched." & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %present, label %metadata, label %failed" & vbCrLf
    Text = Text & "metadata:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %header = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %fields = getelementptr i8, ptr %header, i64 24" & vbCrLf
    Text = Text & "  store ptr %descriptor, ptr %header, align 8" & vbCrLf
    Text = Text & "  store ptr %fields, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8" & vbCrLf
    Text = Text & "  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12" & vbCrLf
    Text = Text & "  %has.layout = icmp ne ptr %layout, null" & vbCrLf
    Text = Text & "  %count = zext i1 %has.layout to i64" & vbCrLf
    Text = Text & "  store ptr %layout, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %count, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %cleanup, ptr %cleanup.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %identity, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; The caller keeps an exact identity root alive while using the returned field address." & vbCrLf
    Text = Text & "define ptr @ube.object.address(ptr %ctx, i64 %identity, ptr %descriptor) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %present, label %type, label %failed" & vbCrLf
    Text = Text & "type:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %fields = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %header = getelementptr i8, ptr %fields, i64 -24" & vbCrLf
    Text = Text & "  %actual = load ptr, ptr %header, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %actual, %descriptor" & vbCrLf
    Text = Text & "  br i1 %same, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %fields" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 13, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Source Object may hide its static class, but each instance retains its exact nominal identity." & vbCrLf
    Text = Text & "define {i1,i64} @ube.object.nominal(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %nothing, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %present, label %descriptor, label %failed" & vbCrLf
    Text = Text & "descriptor:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %fields = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %header = getelementptr i8, ptr %fields, i64 -24" & vbCrLf
    Text = Text & "  %description = load ptr, ptr %header, align 8" & vbCrLf
    Text = Text & "  %described = icmp ne ptr %description, null" & vbCrLf
    Text = Text & "  br i1 %described, label %read.nominal, label %bad" & vbCrLf
    Text = Text & "read.nominal:" & vbCrLf
    Text = Text & "  %nominal = load i64, ptr %description, align 8" & vbCrLf
    Text = Text & "  %valid = icmp sgt i64 %nominal, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %nominal, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "nothing:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} zeroinitializer" & vbCrLf
    Text = Text & "}" & vbCrLf
    ObjectIdentityIR = Text
End Function

Private Function ObjectMonitorIR() As String
    Dim Text As String
    Text = Text & "; Rooted callers remain registered UBE threads for the entire acquired/waiting interval." & vbCrLf
    Text = Text & "define {i1,i64} @ube.monitor.tryenter(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %present, label %inspect, label %failed" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %fields = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr i8, ptr %fields, i64 -16" & vbCrLf
    Text = Text & "  %depth.ptr = getelementptr i8, ptr %fields, i64 -8" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %reenter, label %acquire" & vbCrLf
    Text = Text & "reenter:" & vbCrLf
    Text = Text & "  %depth = load i64, ptr %depth.ptr, align 8" & vbCrLf
    Text = Text & "  %positive = icmp ugt i64 %depth, 0" & vbCrLf
    Text = Text & "  %room = icmp ult i64 %depth, 9223372036854775807" & vbCrLf
    Text = Text & "  %valid = and i1 %positive, %room" & vbCrLf
    Text = Text & "  br i1 %valid, label %increment, label %overflow" & vbCrLf
    Text = Text & "increment:" & vbCrLf
    Text = Text & "  %next = add i64 %depth, 1" & vbCrLf
    Text = Text & "  store i64 %next, ptr %depth.ptr, align 8" & vbCrLf
    Text = Text & "  br label %acquired" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr %owner.ptr, ptr null, ptr %ctx acquire monotonic" & vbCrLf
    Text = Text & "  %won = extractvalue {ptr,i1} %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %initialize, label %busy" & vbCrLf
    Text = Text & "initialize:" & vbCrLf
    Text = Text & "  store i64 1, ptr %depth.ptr, align 8" & vbCrLf
    Text = Text & "  br label %acquired" & vbCrLf
    Text = Text & "acquired:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 1}" & vbCrLf
    Text = Text & "busy:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "overflow:" & vbCrLf
    Text = Text & "  store atomic i64 6, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} zeroinitializer" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Valid compiler-owned release is allocation-free, cannot fail, and preserves Err." & vbCrLf
    Text = Text & "define i1 @ube.monitor.leave(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %present, label %inspect, label %failed" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %fields = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr i8, ptr %fields, i64 -16" & vbCrLf
    Text = Text & "  %depth.ptr = getelementptr i8, ptr %fields, i64 -8" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %read.depth, label %bad" & vbCrLf
    Text = Text & "read.depth:" & vbCrLf
    Text = Text & "  %depth = load i64, ptr %depth.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ugt i64 %depth, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %decrement, label %bad" & vbCrLf
    Text = Text & "decrement:" & vbCrLf
    Text = Text & "  %next = sub i64 %depth, 1" & vbCrLf
    Text = Text & "  store i64 %next, ptr %depth.ptr, align 8" & vbCrLf
    Text = Text & "  %last = icmp eq i64 %next, 0" & vbCrLf
    Text = Text & "  br i1 %last, label %release, label %done" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  store atomic ptr null, ptr %owner.ptr release, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Scheduling backoff only: correctness depends on atomics and roots, never the sleep duration." & vbCrLf
    Text = Text & "define i1 @ube.monitor.yield(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  call void @ube.managed.safe(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @Sleep(i32 1)" & vbCrLf
    Text = Text & "  call void @ube.managed.enter(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Structured cleanup retains both slots on an invalid acquired-state release." & vbCrLf
    Text = Text & "define i1 @ube.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %identity.valid = icmp ne ptr %identity.slot, null" & vbCrLf
    Text = Text & "  %acquired.valid = icmp ne ptr %acquired.slot, null" & vbCrLf
    Text = Text & "  %valid = and i1 %identity.valid, %acquired.valid" & vbCrLf
    Text = Text & "  br i1 %valid, label %inspect, label %bad" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %acquired = load atomic i64, ptr %acquired.slot acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %acquired, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %clear, label %owned" & vbCrLf
    Text = Text & "owned:" & vbCrLf
    Text = Text & "  %held = icmp eq i64 %acquired, 1" & vbCrLf
    Text = Text & "  br i1 %held, label %release, label %bad" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %identity.slot acquire, align 8" & vbCrLf
    Text = Text & "  %released = call i1 @ube.monitor.leave(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  br i1 %released, label %clear, label %failed" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %acquired.slot release, align 8" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %identity.slot, i64 0)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ObjectMonitorIR = Text
End Function
