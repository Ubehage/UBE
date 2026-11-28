Attribute VB_Name = "NativeManagedRuntime"
Option Explicit
' Emits precise managed metadata and root mechanics; collection algorithms remain ordinary UBE.
Public Function NativeManagedIR() As String
    NativeManagedIR = NativeManagedIR & ManagedMetadataIR()
    NativeManagedIR = NativeManagedIR & ManagedSnapshotIR()
    NativeManagedIR = NativeManagedIR & ManagedPublicationIR()
    NativeManagedIR = NativeManagedIR & ManagedThreadsIR()
    NativeManagedIR = NativeManagedIR & ManagedInstallationIR()
    NativeManagedIR = NativeManagedIR & ManagedTextIR()
    NativeManagedIR = NativeManagedIR & CandidateAccessIR()
    NativeManagedIR = NativeManagedIR & ManagedOwnersIR()
    NativeManagedIR = NativeManagedIR & ManagedLayoutsIR()
    NativeManagedIR = NativeManagedIR & ManagedRootsIR()
    NativeManagedIR = NativeManagedIR & ManagedCollectionIR()
    NativeManagedIR = NativeManagedIR & ManagedReclamationIR()
    NativeManagedIR = NativeManagedIR & ManagedCallbackIR()
    NativeManagedIR = NativeManagedIR & ManagedWorkspaceIR()
    NativeManagedIR = NativeManagedIR & ManagedShutdownIR()
End Function

Private Function ManagedShutdownIR() As String
    Dim Text As String
    Text = Text & "; Exact typed payload publication boundary; layout/count are compiler metadata." & vbCrLf
    Text = Text & "define void @ube.managed.publish.range(ptr %ctx, ptr %destination, ptr %layout, i64 %count) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  fence release" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.shutdown(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %present, label %roots, label %done" & vbCrLf
    Text = Text & "roots:" & vbCrLf
    Text = Text & "  %global = getelementptr %ube.managed.state, ptr %state, i32 0, i32 11" & vbCrLf
    Text = Text & "  %roots.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  %root = load ptr, ptr %roots.ptr, align 8" & vbCrLf
    Text = Text & "  %is.global = icmp eq ptr %root, %global" & vbCrLf
    Text = Text & "  %no.roots = icmp eq ptr %root, null" & vbCrLf
    Text = Text & "  %ready = or i1 %is.global, %no.roots" & vbCrLf
    Text = Text & "  br i1 %ready, label %retire, label %busy" & vbCrLf
    Text = Text & "retire:" & vbCrLf
    Text = Text & "  br i1 %is.global, label %pop, label %collect" & vbCrLf
    Text = Text & "pop:" & vbCrLf
    Text = Text & "  call void @ube.managed.root.pop(ptr %ctx, ptr %global)" & vbCrLf
    Text = Text & "  br label %collect" & vbCrLf
    Text = Text & "collect:" & vbCrLf
    Text = Text & "  call void @ube.managed.discard(ptr %ctx)" & vbCrLf
    Text = Text & "  %result = call { i1, i64 } @ube.managed.collect(ptr %ctx, i64 -1)" & vbCrLf
    Text = Text & "  %success = extractvalue { i1, i64 } %result, 0" & vbCrLf
    Text = Text & "  %head = load ptr, ptr %state, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq ptr %head, null" & vbCrLf
    Text = Text & "  %clean = and i1 %success, %empty" & vbCrLf
    Text = Text & "  br i1 %clean, label %detach, label %busy" & vbCrLf
    Text = Text & "detach:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14" & vbCrLf
    Text = Text & "  store atomic ptr null, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  %metadata.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 15" & vbCrLf
    Text = Text & "  %metadata = load ptr, ptr %metadata.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %metadata.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %metadata)" & vbCrLf
    Text = Text & "  %block = getelementptr %ube.block, ptr %state, i64 -1" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "busy:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedShutdownIR = Text
End Function

Private Function ManagedMetadataIR() As String
    Dim Text As String
    ' Record field 12 is trusted, compiler-generated native-owner cleanup; never user code or allocation.
    Text = Text & "%ube.managed.layout = type { i64, i64, ptr, i64, ptr, i64, ptr }" & vbCrLf
    Text = Text & "%ube.managed.array = type { i64, ptr }" & vbCrLf
    Text = Text & "%ube.managed.record = type { ptr, i64, i64, ptr, ptr, i64, i64, ptr, i64, ptr, ptr, i64, ptr }" & vbCrLf
    Text = Text & "%ube.managed.state = type { ptr, ptr, ptr, i64, i64, i64, i64, i64, i64, i64, ptr, %ube.rootframe, i64, ptr, ptr, ptr, i64, i64, i64 }" & vbCrLf
    Text = Text & "@ube.managed.next = internal global i64 1" & vbCrLf
    Text = Text & "" & vbCrLf
    Text = Text & "define internal ptr @ube.managed.state(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14" & vbCrLf
    Text = Text & "  %state = load atomic ptr, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  ret ptr %state" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "" & vbCrLf
    Text = Text & "define internal i64 @ube.managed.issue() {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  br label %attempt" & vbCrLf
    Text = Text & "attempt:" & vbCrLf
    Text = Text & "  %old = load atomic i64, ptr @ube.managed.next seq_cst, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %old, 9223372036854775807" & vbCrLf
    Text = Text & "  br i1 %valid, label %issue, label %exhausted" & vbCrLf
    Text = Text & "issue:" & vbCrLf
    Text = Text & "  %next = add i64 %old, 1" & vbCrLf
    Text = Text & "  %pair = cmpxchg ptr @ube.managed.next, i64 %old, i64 %next seq_cst seq_cst" & vbCrLf
    Text = Text & "  %won = extractvalue {i64,i1} %pair, 1" & vbCrLf
    Text = Text & "  br i1 %won, label %done, label %attempt" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i64 %old" & vbCrLf
    Text = Text & "exhausted:" & vbCrLf
    Text = Text & "  ret i64 0" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "" & vbCrLf
    Text = Text & "; Identity lookup visits allocation metadata, never graph edges." & vbCrLf
    Text = Text & "define internal ptr @ube.managed.find(ptr %state, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %valid = icmp sgt i64 %identity, 0" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  %ready = and i1 %valid, %present" & vbCrLf
    Text = Text & "  br i1 %ready, label %head, label %absent" & vbCrLf
    Text = Text & "head:" & vbCrLf
    Text = Text & "  %first = load atomic ptr, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first, %head ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %absent" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %id = load i64, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %id, %identity" & vbCrLf
    Text = Text & "  br i1 %same, label %found, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "found:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "absent:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "" & vbCrLf
    Text = Text & "; A frame only links exact metadata; it neither allocates nor walks managed edges." & vbCrLf
    Text = Text & "define void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr %base, ptr %layout, i64 %count) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  %old = load ptr, ptr %head, align 8" & vbCrLf
    Text = Text & "  %base.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 1" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 2" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 3" & vbCrLf
    Text = Text & "  store ptr %old, ptr %frame, align 8" & vbCrLf
    Text = Text & "  store ptr %base, ptr %base.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %layout, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %count, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %frame, ptr %head release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "" & vbCrLf
    Text = Text & "; Construction candidates are unpublished; dropping their root cannot run user code." & vbCrLf
    Text = Text & "define void @ube.managed.root.pop(ptr %ctx, ptr %frame) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %link = phi ptr [ %candidates, %entry ], [ %link, %abandon ], [ %next.ptr, %keep ]" & vbCrLf
    Text = Text & "  %candidate = load ptr, ptr %link, align 8" & vbCrLf
    Text = Text & "  %done = icmp eq ptr %candidate, null" & vbCrLf
    Text = Text & "  br i1 %done, label %unlink, label %inspect" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %next.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 4" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 3" & vbCrLf
    Text = Text & "  %owner = load ptr, ptr %owner.ptr, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %frame" & vbCrLf
    Text = Text & "  br i1 %mine, label %abandon, label %keep" & vbCrLf
    Text = Text & "abandon:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %next.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %next, ptr %link, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %owner.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %next.ptr, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "keep:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  %previous = load ptr, ptr %frame, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %previous, ptr %head release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.root.restore(ptr %ctx, ptr %sentinel) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %frame = load ptr, ptr %head, align 8" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %frame, null" & vbCrLf
    Text = Text & "  br i1 %present, label %pop, label %done" & vbCrLf
    Text = Text & "pop:" & vbCrLf
    Text = Text & "  %last = icmp eq ptr %frame, %sentinel" & vbCrLf
    Text = Text & "  call void @ube.managed.root.pop(ptr %ctx, ptr %frame)" & vbCrLf
    Text = Text & "  br i1 %last, label %done, label %scan" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedMetadataIR = Text
End Function

Private Function ManagedSnapshotIR() As String
    Dim Text As String
    Text = Text & "; Snapshot queries are legal only for the elected coordinator." & vbCrLf
    Text = Text & "define internal ptr @ube.managed.owned(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %bad" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %state" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.snapshot.counts(ptr %ctx, ptr %allocations, ptr %roots) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %allocation.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %root.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9" & vbCrLf
    Text = Text & "  %allocation.count = load i64, ptr %allocation.ptr, align 8" & vbCrLf
    Text = Text & "  %root.count = load i64, ptr %root.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp sge i64 %root.count, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %publish, label %snapshot.error" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store i64 %allocation.count, ptr %allocations, align 8" & vbCrLf
    Text = Text & "  store i64 %root.count, ptr %roots, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "snapshot.error:" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6" & vbCrLf
    Text = Text & "  %error = load i64, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %error, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %bad" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.allocation.at(ptr %ctx, i64 %index, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %check, label %failed" & vbCrLf
    Text = Text & "check:" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %count = load i64, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %index, %count" & vbCrLf
    Text = Text & "  br i1 %valid, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10" & vbCrLf
    Text = Text & "  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8" & vbCrLf
    Text = Text & "  %slot = getelementptr i64, ptr %snapshot.data, i64 %index" & vbCrLf
    Text = Text & "  %identity = load i64, ptr %slot, align 8" & vbCrLf
    Text = Text & "  store i64 %identity, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.mark(ptr %ctx, i64 %identity, ptr %fresh) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %phase, label %failed" & vbCrLf
    Text = Text & "phase:" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %phase.value = load i64, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  %marking = icmp eq i64 %phase.value, 1" & vbCrLf
    Text = Text & "  br i1 %marking, label %empty, label %bad" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %unchanged, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %bad" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  %mark = load i64, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  %first = icmp eq i64 %mark, 0" & vbCrLf
    Text = Text & "  br i1 %first, label %publish, label %unchanged" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store i64 1, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 -1, ptr %fresh, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "unchanged:" & vbCrLf
    Text = Text & "  store i64 0, ptr %fresh, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.marked(ptr %ctx, i64 %identity, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %empty, label %failed" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %unmarked, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  %mark = load i64, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  %yes = icmp ne i64 %mark, 0" & vbCrLf
    Text = Text & "  %value = select i1 %yes, i64 -1, i64 0" & vbCrLf
    Text = Text & "  store i64 %value, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "unmarked:" & vbCrLf
    Text = Text & "  store i64 0, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.seal(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ok = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ok, label %phase, label %failed" & vbCrLf
    Text = Text & "phase:" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %old = load i64, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  %marking = icmp eq i64 %old, 1" & vbCrLf
    Text = Text & "  br i1 %marking, label %commit, label %bad" & vbCrLf
    Text = Text & "commit:" & vbCrLf
    Text = Text & "  store i64 2, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedSnapshotIR = Text
End Function

Private Function ManagedPublicationIR() As String
    Dim Text As String
    Text = Text & "; Root transfer primitives are noninterruptible and never poll or allocate." & vbCrLf
    Text = Text & "define i64 @ube.managed.load(ptr %ctx, ptr %source, ptr %root) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %source acquire, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %identity, ptr %root release, align 8" & vbCrLf
    Text = Text & "  ret i64 %identity" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  store atomic i64 %identity, ptr %destination release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.return(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8" & vbCrLf
    Text = Text & "  store atomic i64 %identity, ptr %handoff release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i64 @ube.managed.take(ptr %ctx, ptr %root) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %handoff acquire, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %identity, ptr %root release, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %handoff release, align 8" & vbCrLf
    Text = Text & "  ret i64 %identity" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.discard(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %handoff release, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedPublicationIR = Text
End Function

Private Function ManagedThreadsIR() As String
    Dim Text As String
    Text = Text & "define void @ube.managed.thread.register(ptr %ctx, i64 %initial) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %roots = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5" & vbCrLf
    Text = Text & "  %next = getelementptr %ube.thread, ptr %ctx, i32 0, i32 6" & vbCrLf
    Text = Text & "  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7" & vbCrLf
    Text = Text & "  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %roots, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %candidates, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %initial, ptr %status release, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %handoff release, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15" & vbCrLf
    Text = Text & "  %old = load ptr, ptr %head, align 8" & vbCrLf
    Text = Text & "  store ptr %old, ptr %next, align 8" & vbCrLf
    Text = Text & "  store ptr %ctx, ptr %head, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.thread.unregister(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %link = phi ptr [ %head, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %thread = load ptr, ptr %link, align 8" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %thread, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %done" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %next = getelementptr %ube.thread, ptr %thread, i32 0, i32 6" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %thread, %ctx" & vbCrLf
    Text = Text & "  br i1 %same, label %unlink, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  %following = load ptr, ptr %next, align 8" & vbCrLf
    Text = Text & "  store ptr %following, ptr %link, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %next, align 8" & vbCrLf
    Text = Text & "  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7" & vbCrLf
    Text = Text & "  store atomic i64 4, ptr %status release, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Calling threads publish every exact root before invoking this gate." & vbCrLf
    Text = Text & "define void @ube.managed.enter(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %present, label %admit, label %plain" & vbCrLf
    Text = Text & "plain:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %status seq_cst, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "admit:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %status seq_cst, align 8" & vbCrLf
    Text = Text & "  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %request = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %requested = icmp ne i64 %request, 0" & vbCrLf
    Text = Text & "  br i1 %requested, label %inspect.owner, label %done" & vbCrLf
    Text = Text & "inspect.owner:" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %done, label %park" & vbCrLf
    Text = Text & "park:" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %status seq_cst, align 8" & vbCrLf
    Text = Text & "  br label %wait" & vbCrLf
    Text = Text & "wait:" & vbCrLf
    Text = Text & "  %active = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %finished = icmp eq i64 %active, 0" & vbCrLf
    Text = Text & "  br i1 %finished, label %admit, label %yield" & vbCrLf
    Text = Text & "yield:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %wait" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define void @ube.managed.safe(ptr %ctx) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7" & vbCrLf
    Text = Text & "  store atomic i64 2, ptr %status seq_cst, align 8" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedThreadsIR = Text
End Function

Private Function ManagedInstallationIR() As String
    Dim Text As String
    Text = Text & "; Installation occurs before project/module initialization and worker publication." & vbCrLf
    Text = Text & "define i1 @ube.managed.install(ptr %ctx, ptr %callback) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %callback, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %existing, label %bad" & vbCrLf
    Text = Text & "existing:" & vbCrLf
    Text = Text & "  %previous = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %installed = icmp ne ptr %previous, null" & vbCrLf
    Text = Text & "  br i1 %installed, label %compare, label %allocate" & vbCrLf
    Text = Text & "compare:" & vbCrLf
    Text = Text & "  %old.callback.ptr = getelementptr %ube.managed.state, ptr %previous, i32 0, i32 1" & vbCrLf
    Text = Text & "  %old.callback = load ptr, ptr %old.callback.ptr, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %old.callback, %callback" & vbCrLf
    Text = Text & "  br i1 %same, label %done, label %bad" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %end = getelementptr %ube.managed.state, ptr null, i64 1" & vbCrLf
    Text = Text & "  %bytes = ptrtoint ptr %end to i64" & vbCrLf
    Text = Text & "  %rounded = add i64 %bytes, 7" & vbCrLf
    Text = Text & "  %cells = lshr i64 %rounded, 3" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 %cells, i64 1)" & vbCrLf
    Text = Text & "  %allocated = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %allocated, label %publish, label %memory" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %state = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %callback.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  store ptr %callback, ptr %callback.ptr, align 8" & vbCrLf
    Text = Text & "  %pressure.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 18" & vbCrLf
    Text = Text & "  store i64 256, ptr %pressure.ptr, align 8" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14" & vbCrLf
    Text = Text & "  store atomic ptr %state, ptr %slot release, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; The program owns this frame's storage until orderly managed shutdown." & vbCrLf
    Text = Text & "define void @ube.managed.globals(ptr %ctx, ptr %layout) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %frame, label %done" & vbCrLf
    Text = Text & "frame:" & vbCrLf
    Text = Text & "  %root = getelementptr %ube.managed.state, ptr %state, i32 0, i32 11" & vbCrLf
    Text = Text & "  %base.ptr = getelementptr %ube.rootframe, ptr %root, i32 0, i32 1" & vbCrLf
    Text = Text & "  %old = load ptr, ptr %base.ptr, align 8" & vbCrLf
    Text = Text & "  %registered = icmp ne ptr %old, null" & vbCrLf
    Text = Text & "  br i1 %registered, label %done, label %register" & vbCrLf
    Text = Text & "register:" & vbCrLf
    Text = Text & "  %base = call ptr @ube.storage.address(ptr %ctx, i64 0)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %layout, null" & vbCrLf
    Text = Text & "  %count = zext i1 %present to i64" & vbCrLf
    Text = Text & "  call void @ube.managed.root.push(ptr %ctx, ptr %root, ptr %base, ptr %layout, i64 %count)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedInstallationIR = Text
End Function

Private Function ManagedTextIR() As String
    Dim Text As String
    Text = Text & "define internal ptr @ube.text.find(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %kind, label %bad" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  %value = load i64, ptr %kind.ptr, align 8" & vbCrLf
    Text = Text & "  %text = icmp eq i64 %value, 1" & vbCrLf
    Text = Text & "  br i1 %text, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.managed.candidate(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %owner, label %bad" & vbCrLf
    Text = Text & "owner:" & vbCrLf
    Text = Text & "  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  %thread = load ptr, ptr %thread.ptr, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %thread, %ctx" & vbCrLf
    Text = Text & "  %frame.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %frame = load ptr, ptr %frame.ptr, align 8" & vbCrLf
    Text = Text & "  %private = icmp ne ptr %frame, null" & vbCrLf
    Text = Text & "  %owned = and i1 %mine, %private" & vbCrLf
    Text = Text & "  br i1 %owned, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal ptr @ube.text.candidate(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %candidate, label %failed" & vbCrLf
    Text = Text & "candidate:" & vbCrLf
    Text = Text & "  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  ret ptr %owned" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal void @ube.managed.unlink(ptr %ctx, ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %link = phi ptr [ %head, %entry ], [ %next.ptr, %advance ]" & vbCrLf
    Text = Text & "  %item = load ptr, ptr %link, align 8" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %item, null" & vbCrLf
    Text = Text & "  br i1 %present, label %inspect, label %done" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %next.ptr = getelementptr %ube.managed.record, ptr %item, i32 0, i32 4" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %item, %record" & vbCrLf
    Text = Text & "  br i1 %same, label %unlink, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %next.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %next, ptr %link, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %next.ptr, align 8" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  store ptr null, ptr %owner.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %thread.ptr, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define {i1,i64} @ube.text.length(ptr %ctx, ptr %slot, i1 %scalars) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read, label %failed" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %scalars.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 6" & vbCrLf
    Text = Text & "  %length.ptr = select i1 %scalars, ptr %scalars.ptr, ptr %bytes.ptr" & vbCrLf
    Text = Text & "  %length = load i64, ptr %length.ptr, align 8" & vbCrLf
    Text = Text & "  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %length, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} zeroinitializer" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.read(ptr %ctx, ptr %slot, i64 %index, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %slot acquire, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %bounds, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %check, label %failed" & vbCrLf
    Text = Text & "check:" & vbCrLf
    Text = Text & "  %length.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %length = load i64, ptr %length.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %index, %length" & vbCrLf
    Text = Text & "  br i1 %valid, label %read, label %bounds" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %payload = load ptr, ptr %payload.ptr, align 8" & vbCrLf
    Text = Text & "  %byte.ptr = getelementptr i8, ptr %payload, i64 %index" & vbCrLf
    Text = Text & "  %byte = load i8, ptr %byte.ptr, align 1" & vbCrLf
    Text = Text & "  %value = zext i8 %byte to i64" & vbCrLf
    Text = Text & "  store i64 %value, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bounds:" & vbCrLf
    Text = Text & "  store atomic i64 9, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Allocation pressure uses the existing precise collector, never a new heap or worker." & vbCrLf
    Text = Text & "define internal void @ube.managed.pressure(ptr %ctx, ptr %state) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %recursive = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %recursive, label %done, label %enter" & vbCrLf
    Text = Text & "enter:" & vbCrLf
    Text = Text & "  call void @ube.managed.enter(ptr %ctx)" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %request = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %requested = icmp ne i64 %request, 0" & vbCrLf
    Text = Text & "  br i1 %requested, label %unlock, label %pressure" & vbCrLf
    Text = Text & "pressure:" & vbCrLf
    Text = Text & "  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17" & vbCrLf
    Text = Text & "  %limit.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 18" & vbCrLf
    Text = Text & "  %live = load i64, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %limit = load i64, ptr %limit.ptr, align 8" & vbCrLf
    Text = Text & "  %due = icmp uge i64 %live, %limit" & vbCrLf
    Text = Text & "  br i1 %due, label %reserve, label %unlock" & vbCrLf
    Text = Text & "reserve:" & vbCrLf
    Text = Text & "  %half = lshr i64 %live, 1" & vbCrLf
    Text = Text & "  %small = icmp ult i64 %half, 256" & vbCrLf
    Text = Text & "  %budget = select i1 %small, i64 256, i64 %half" & vbCrLf
    Text = Text & "  %next = add i64 %live, %budget" & vbCrLf
    Text = Text & "  store i64 %next, ptr %limit.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.collect(ptr %ctx, i64 0)" & vbCrLf
    Text = Text & "  call void @ube.managed.enter(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %survivors = load i64, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %survivor.half = lshr i64 %survivors, 1" & vbCrLf
    Text = Text & "  %survivor.small = icmp ult i64 %survivor.half, 256" & vbCrLf
    Text = Text & "  %survivor.budget = select i1 %survivor.small, i64 256, i64 %survivor.half" & vbCrLf
    Text = Text & "  %rearmed = add i64 %survivors, %survivor.budget" & vbCrLf
    Text = Text & "  store i64 %rearmed, ptr %limit.ptr, align 8" & vbCrLf
    Text = Text & "  br label %unlock" & vbCrLf
    Text = Text & "unlock:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Reserves collection metadata before publishing a managed record; collection never grows it." & vbCrLf
    Text = Text & "define internal i1 @ube.managed.register(ptr %ctx, ptr %state, ptr %record) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %retry.used = alloca i1, align 1" & vbCrLf
    Text = Text & "  store i1 false, ptr %retry.used, align 1" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14" & vbCrLf
    Text = Text & "  %buffer.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 15" & vbCrLf
    Text = Text & "  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16" & vbCrLf
    Text = Text & "  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17" & vbCrLf
    Text = Text & "  br label %lock" & vbCrLf
    Text = Text & "lock:" & vbCrLf
    Text = Text & "  call void @ube.managed.enter(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %request = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %phase = load i64, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  %lease = load ptr, ptr %lease.ptr, align 8" & vbCrLf
    Text = Text & "  %requested = icmp ne i64 %request, 0" & vbCrLf
    Text = Text & "  %phased = icmp ne i64 %phase, 0" & vbCrLf
    Text = Text & "  %leased = icmp ne ptr %lease, null" & vbCrLf
    Text = Text & "  %active.phase = or i1 %requested, %phased" & vbCrLf
    Text = Text & "  %active = or i1 %active.phase, %leased" & vbCrLf
    Text = Text & "  br i1 %active, label %park, label %count" & vbCrLf
    Text = Text & "park:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %failed, label %lock" & vbCrLf
    Text = Text & "count:" & vbCrLf
    Text = Text & "  %live = load i64, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %count.fits = icmp ult i64 %live, 2147483647" & vbCrLf
    Text = Text & "  br i1 %count.fits, label %capacity, label %unlock.failed" & vbCrLf
    Text = Text & "capacity:" & vbCrLf
    Text = Text & "  %needed = add i64 %live, 1" & vbCrLf
    Text = Text & "  %old.capacity = load i64, ptr %capacity.ptr, align 8" & vbCrLf
    Text = Text & "  %fits = icmp ule i64 %needed, %old.capacity" & vbCrLf
    Text = Text & "  br i1 %fits, label %publish, label %grow" & vbCrLf
    Text = Text & "grow:" & vbCrLf
    Text = Text & "  %doubled = shl i64 %old.capacity, 1" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %old.capacity, 0" & vbCrLf
    Text = Text & "  %initial = select i1 %empty, i64 16, i64 %doubled" & vbCrLf
    Text = Text & "  %too.large = icmp ugt i64 %initial, 2147483647" & vbCrLf
    Text = Text & "  %new.capacity = select i1 %too.large, i64 2147483647, i64 %initial" & vbCrLf
    Text = Text & "  %cells = shl i64 %new.capacity, 1" & vbCrLf
    Text = Text & "  %buffer = call ptr @ube.memory.new.locked(ptr %ctx, i64 %cells, i64 1)" & vbCrLf
    Text = Text & "  %allocated = icmp ne ptr %buffer, null" & vbCrLf
    Text = Text & "  br i1 %allocated, label %replace, label %retry" & vbCrLf
    Text = Text & "replace:" & vbCrLf
    Text = Text & "  %snapshot = getelementptr %ube.block, ptr %buffer, i64 1" & vbCrLf
    Text = Text & "  %queue = getelementptr i64, ptr %snapshot, i64 %new.capacity" & vbCrLf
    Text = Text & "  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10" & vbCrLf
    Text = Text & "  %queue.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 13" & vbCrLf
    Text = Text & "  %old.buffer = load ptr, ptr %buffer.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %snapshot, ptr %snapshot.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %queue, ptr %queue.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %buffer, ptr %buffer.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %new.capacity, ptr %capacity.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %old.buffer)" & vbCrLf
    Text = Text & "  br label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %old.head = load atomic ptr, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  store ptr %old.head, ptr %record, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %record, ptr %state release, align 8" & vbCrLf
    Text = Text & "  store i64 %needed, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "retry:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %retried = load i1, ptr %retry.used, align 1" & vbCrLf
    Text = Text & "  br i1 %retried, label %failed, label %collect" & vbCrLf
    Text = Text & "collect:" & vbCrLf
    Text = Text & "  store i1 true, ptr %retry.used, align 1" & vbCrLf
    Text = Text & "  %collected = call {i1,i64} @ube.managed.collect(ptr %ctx, i64 0)" & vbCrLf
    Text = Text & "  br label %lock" & vbCrLf
    Text = Text & "unlock.failed:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.create(ptr %ctx, i64 %bytes, i64 %scalars, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %negative = icmp slt i64 %bytes, 0" & vbCrLf
    Text = Text & "  %negative.scalars = icmp slt i64 %scalars, 0" & vbCrLf
    Text = Text & "  %excess.scalars = icmp ugt i64 %scalars, %bytes" & vbCrLf
    Text = Text & "  %zero.bytes = icmp eq i64 %bytes, 0" & vbCrLf
    Text = Text & "  %zero.scalars = icmp eq i64 %scalars, 0" & vbCrLf
    Text = Text & "  %one.zero = xor i1 %zero.bytes, %zero.scalars" & vbCrLf
    Text = Text & "  %a = or i1 %negative, %negative.scalars" & vbCrLf
    Text = Text & "  %b = or i1 %excess.scalars, %one.zero" & vbCrLf
    Text = Text & "  %invalid = or i1 %a, %b" & vbCrLf
    Text = Text & "  br i1 %invalid, label %bad, label %empty" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  br i1 %zero.bytes, label %zero, label %owner" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  store i64 0, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "owner:" & vbCrLf
    Text = Text & "  %created = call i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 %scalars, i64 1, ptr %output)" & vbCrLf
    Text = Text & "  ret i1 %created" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 %scalars, i64 %kind, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %positive = icmp sgt i64 %bytes, 0" & vbCrLf
    Text = Text & "  %kind.valid = icmp sgt i64 %kind, 0" & vbCrLf
    Text = Text & "  %valid = and i1 %positive, %kind.valid" & vbCrLf
    Text = Text & "  br i1 %valid, label %owner, label %bad" & vbCrLf
    Text = Text & "owner:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  %frame.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4" & vbCrLf
    Text = Text & "  %frame = load ptr, ptr %frame.ptr, align 8" & vbCrLf
    Text = Text & "  %framed = icmp ne ptr %frame, null" & vbCrLf
    Text = Text & "  %owned = and i1 %ready, %framed" & vbCrLf
    Text = Text & "  br i1 %owned, label %size, label %bad" & vbCrLf
    Text = Text & "size:" & vbCrLf
    Text = Text & "  %header.end = getelementptr %ube.managed.record, ptr null, i64 1" & vbCrLf
    Text = Text & "  %header.bytes = ptrtoint ptr %header.end to i64" & vbCrLf
    Text = Text & "  %maximum.total = sub i64 9223372036854775807, %header.bytes" & vbCrLf
    Text = Text & "  %maximum.bytes = sub i64 %maximum.total, 1023" & vbCrLf
    Text = Text & "  %too.large = icmp ugt i64 %bytes, %maximum.bytes" & vbCrLf
    Text = Text & "  br i1 %too.large, label %memory, label %allocate" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  call void @ube.managed.pressure(ptr %ctx, ptr %state)" & vbCrLf
    Text = Text & "  %total = add i64 %bytes, %header.bytes" & vbCrLf
    Text = Text & "  %rounded = add i64 %total, 1023" & vbCrLf
    Text = Text & "  %chunks = lshr i64 %rounded, 10" & vbCrLf
    Text = Text & "  %block = call ptr @ube.memory.new(ptr %ctx, i64 %chunks, i64 128)" & vbCrLf
    Text = Text & "  %allocated = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %allocated, label %issue, label %memory" & vbCrLf
    Text = Text & "issue:" & vbCrLf
    Text = Text & "  %identity = call i64 @ube.managed.issue()" & vbCrLf
    Text = Text & "  %issued = icmp ne i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %issued, label %initialize, label %discard" & vbCrLf
    Text = Text & "discard:" & vbCrLf
    Text = Text & "  call void @ube.block.drop(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  br label %memory" & vbCrLf
    Text = Text & "initialize:" & vbCrLf
    Text = Text & "  %record = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  %payload = getelementptr %ube.managed.record, ptr %record, i64 1" & vbCrLf
    Text = Text & "  %id.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %candidate.next = getelementptr %ube.managed.record, ptr %record, i32 0, i32 4" & vbCrLf
    Text = Text & "  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %scalars.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 6" & vbCrLf
    Text = Text & "  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  store i64 %identity, ptr %id.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %frame, ptr %owner.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %bytes, ptr %bytes.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %scalars, ptr %scalars.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %payload, ptr %payload.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %ctx, ptr %thread.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %kind, ptr %kind.ptr, align 8" & vbCrLf
    Text = Text & "  %registered = call i1 @ube.managed.register(ptr %ctx, ptr %state, ptr %record)" & vbCrLf
    Text = Text & "  br i1 %registered, label %candidate, label %discard" & vbCrLf
    Text = Text & "candidate:" & vbCrLf
    Text = Text & "  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5" & vbCrLf
    Text = Text & "  %old.candidate = load ptr, ptr %candidates, align 8" & vbCrLf
    Text = Text & "  store ptr %old.candidate, ptr %candidate.next, align 8" & vbCrLf
    Text = Text & "  store ptr %record, ptr %candidates, align 8" & vbCrLf
    Text = Text & "  store i64 %identity, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.write(ptr %ctx, i64 %identity, i64 %index, i64 %value) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %bounds, label %failed" & vbCrLf
    Text = Text & "bounds:" & vbCrLf
    Text = Text & "  %length.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %length = load i64, ptr %length.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %index, %length" & vbCrLf
    Text = Text & "  br i1 %valid, label %byte, label %range" & vbCrLf
    Text = Text & "byte:" & vbCrLf
    Text = Text & "  %byte.valid = icmp ule i64 %value, 255" & vbCrLf
    Text = Text & "  br i1 %byte.valid, label %write, label %bad" & vbCrLf
    Text = Text & "write:" & vbCrLf
    Text = Text & "  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %payload = load ptr, ptr %payload.ptr, align 8" & vbCrLf
    Text = Text & "  %address = getelementptr i8, ptr %payload, i64 %index" & vbCrLf
    Text = Text & "  %narrow = trunc i64 %value to i8" & vbCrLf
    Text = Text & "  store i8 %narrow, ptr %address, align 1" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  store atomic i64 9, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.publish(ptr %ctx, ptr %destination, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %commit, label %failed" & vbCrLf
    Text = Text & "commit:" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity)" & vbCrLf
    Text = Text & "  call void @ube.managed.unlink(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 0)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.abandon(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %done, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %unlink, label %failed" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  call void @ube.managed.unlink(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Variant payload headers are immutable; exact layout metadata describes only data." & vbCrLf
    Text = Text & "define internal ptr @ube.variant.find(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %kind, label %bad" & vbCrLf
    Text = Text & "kind:" & vbCrLf
    Text = Text & "  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11" & vbCrLf
    Text = Text & "  %kind.value = load i64, ptr %kind.ptr, align 8" & vbCrLf
    Text = Text & "  %variant = icmp eq i64 %kind.value, 2" & vbCrLf
    Text = Text & "  br i1 %variant, label %done, label %bad" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret ptr %record" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define ptr @ube.variant.payload(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read, label %failed" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  ret ptr %data" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret ptr null" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.variant.create(ptr %ctx, i64 %tag, i64 %nominal, i64 %rank, i64 %cells, ptr %layout, ptr %cleanup, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %positive = icmp sgt i64 %tag, 0" & vbCrLf
    Text = Text & "  %tag.bounded = icmp ult i64 %tag, 16384" & vbCrLf
    Text = Text & "  %nominal.valid = icmp sge i64 %nominal, 0" & vbCrLf
    Text = Text & "  %rank.valid = icmp sge i64 %rank, 0" & vbCrLf
    Text = Text & "  %a = and i1 %positive, %tag.bounded" & vbCrLf
    Text = Text & "  %b = and i1 %nominal.valid, %rank.valid" & vbCrLf
    Text = Text & "  %valid = and i1 %a, %b" & vbCrLf
    Text = Text & "  br i1 %valid, label %extent, label %bad" & vbCrLf
    Text = Text & "extent:" & vbCrLf
    Text = Text & "  %fits = icmp ule i64 %cells, 1152921504606846971" & vbCrLf
    Text = Text & "  br i1 %fits, label %allocate, label %memory" & vbCrLf
    Text = Text & "allocate:" & vbCrLf
    Text = Text & "  %payload.bytes = mul i64 %cells, 8" & vbCrLf
    Text = Text & "  %bytes = add i64 %payload.bytes, 32" & vbCrLf
    Text = Text & "  %allocated = call i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 0, i64 2, ptr %output)" & vbCrLf
    Text = Text & "  br i1 %allocated, label %initialize, label %failed" & vbCrLf
    Text = Text & "initialize:" & vbCrLf
    Text = Text & "  %identity = load i64, ptr %output, align 8" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %header = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %nominal.ptr = getelementptr i64, ptr %header, i64 1" & vbCrLf
    Text = Text & "  %rank.ptr = getelementptr i64, ptr %header, i64 2" & vbCrLf
    Text = Text & "  %cells.ptr = getelementptr i64, ptr %header, i64 3" & vbCrLf
    Text = Text & "  %data = getelementptr i64, ptr %header, i64 4" & vbCrLf
    Text = Text & "  store i64 %tag, ptr %header, align 8" & vbCrLf
    Text = Text & "  store i64 %nominal, ptr %nominal.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %rank, ptr %rank.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %cells, ptr %cells.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %data, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7" & vbCrLf
    Text = Text & "  %repeat.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8" & vbCrLf
    Text = Text & "  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12" & vbCrLf
    Text = Text & "  store ptr %layout, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  %has.layout = icmp ne ptr %layout, null" & vbCrLf
    Text = Text & "  %repeat = select i1 %has.layout, i64 1, i64 0" & vbCrLf
    Text = Text & "  store i64 %repeat, ptr %repeat.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %cleanup, ptr %cleanup.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "memory:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.variant.info(ptr %ctx, i64 %identity, ptr %tag.out, ptr %nominal.out, ptr %rank.out, ptr %cells.out) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %read" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %data, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %header, label %failed" & vbCrLf
    Text = Text & "header:" & vbCrLf
    Text = Text & "  %tag.ptr = getelementptr i64, ptr %data, i64 -4" & vbCrLf
    Text = Text & "  %nominal.ptr = getelementptr i64, ptr %data, i64 -3" & vbCrLf
    Text = Text & "  %rank.ptr = getelementptr i64, ptr %data, i64 -2" & vbCrLf
    Text = Text & "  %cells.ptr = getelementptr i64, ptr %data, i64 -1" & vbCrLf
    Text = Text & "  %tag.value = load i64, ptr %tag.ptr, align 8" & vbCrLf
    Text = Text & "  %nominal.value = load i64, ptr %nominal.ptr, align 8" & vbCrLf
    Text = Text & "  %rank.value = load i64, ptr %rank.ptr, align 8" & vbCrLf
    Text = Text & "  %cells.value = load i64, ptr %cells.ptr, align 8" & vbCrLf
    Text = Text & "  br label %commit" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  br label %commit" & vbCrLf
    Text = Text & "commit:" & vbCrLf
    Text = Text & "  %tag = phi i64 [0, %zero], [%tag.value, %header]" & vbCrLf
    Text = Text & "  %nominal = phi i64 [0, %zero], [%nominal.value, %header]" & vbCrLf
    Text = Text & "  %rank = phi i64 [0, %zero], [%rank.value, %header]" & vbCrLf
    Text = Text & "  %cells = phi i64 [0, %zero], [%cells.value, %header]" & vbCrLf
    Text = Text & "  store i64 %tag, ptr %tag.out, align 8" & vbCrLf
    Text = Text & "  store i64 %nominal, ptr %nominal.out, align 8" & vbCrLf
    Text = Text & "  store i64 %rank, ptr %rank.out, align 8" & vbCrLf
    Text = Text & "  store i64 %cells, ptr %cells.out, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define {i1,i64} @ube.variant.tag(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %read" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %data, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %header, label %failed" & vbCrLf
    Text = Text & "header:" & vbCrLf
    Text = Text & "  %tag.ptr = getelementptr i64, ptr %data, i64 -4" & vbCrLf
    Text = Text & "  %tag = load i64, ptr %tag.ptr, align 8" & vbCrLf
    Text = Text & "  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %tag, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 0}" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define {i1,i64} @ube.variant.scalar(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %read" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %data, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %header, label %failed" & vbCrLf
    Text = Text & "header:" & vbCrLf
    Text = Text & "  %tag.ptr = getelementptr i64, ptr %data, i64 -4" & vbCrLf
    Text = Text & "  %rank.ptr = getelementptr i64, ptr %data, i64 -2" & vbCrLf
    Text = Text & "  %cells.ptr = getelementptr i64, ptr %data, i64 -1" & vbCrLf
    Text = Text & "  %tag = load i64, ptr %tag.ptr, align 8" & vbCrLf
    Text = Text & "  %rank = load i64, ptr %rank.ptr, align 8" & vbCrLf
    Text = Text & "  %cells = load i64, ptr %cells.ptr, align 8" & vbCrLf
    Text = Text & "  %one = icmp eq i64 %cells, 1" & vbCrLf
    Text = Text & "  %not.array = icmp eq i64 %rank, 0" & vbCrLf
    Text = Text & "  %simple = icmp ult i64 %tag, 36" & vbCrLf
    Text = Text & "  %not.null = icmp ne i64 %tag, 1" & vbCrLf
    Text = Text & "  %a = and i1 %one, %not.array" & vbCrLf
    Text = Text & "  %b = and i1 %simple, %not.null" & vbCrLf
    Text = Text & "  %scalar = and i1 %a, %b" & vbCrLf
    Text = Text & "  br i1 %scalar, label %payload, label %mismatch" & vbCrLf
    Text = Text & "payload:" & vbCrLf
    Text = Text & "  %value = load i64, ptr %data, align 8" & vbCrLf
    Text = Text & "  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %value, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "mismatch:" & vbCrLf
    Text = Text & "  store atomic i64 13, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 0}" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.variant.publish(ptr %ctx, ptr %destination, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %candidate, label %failed" & vbCrLf
    Text = Text & "candidate:" & vbCrLf
    Text = Text & "  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %private = icmp ne ptr %owned, null" & vbCrLf
    Text = Text & "  br i1 %private, label %commit, label %failed" & vbCrLf
    Text = Text & "commit:" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity)" & vbCrLf
    Text = Text & "  call void @ube.managed.unlink(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 0)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.variant.abandon(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %done, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %candidate, label %failed" & vbCrLf
    Text = Text & "candidate:" & vbCrLf
    Text = Text & "  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %private = icmp ne ptr %owned, null" & vbCrLf
    Text = Text & "  br i1 %private, label %unlink, label %failed" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  call void @ube.managed.unlink(ptr %ctx, ptr %record)" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Checked nominal extraction never treats structurally equal payloads as the same type." & vbCrLf
    Text = Text & "define i1 @ube.variant.match(ptr %ctx, i64 %identity, i64 %tag, i64 %nominal, i64 %rank, i64 %cells) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %mismatch, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %data, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %header, label %failed" & vbCrLf
    Text = Text & "header:" & vbCrLf
    Text = Text & "  %tag.ptr = getelementptr i64, ptr %data, i64 -4" & vbCrLf
    Text = Text & "  %nominal.ptr = getelementptr i64, ptr %data, i64 -3" & vbCrLf
    Text = Text & "  %rank.ptr = getelementptr i64, ptr %data, i64 -2" & vbCrLf
    Text = Text & "  %cells.ptr = getelementptr i64, ptr %data, i64 -1" & vbCrLf
    Text = Text & "  %actual.tag = load i64, ptr %tag.ptr, align 8" & vbCrLf
    Text = Text & "  %actual.nominal = load i64, ptr %nominal.ptr, align 8" & vbCrLf
    Text = Text & "  %actual.rank = load i64, ptr %rank.ptr, align 8" & vbCrLf
    Text = Text & "  %actual.cells = load i64, ptr %cells.ptr, align 8" & vbCrLf
    Text = Text & "  %tag.equal = icmp eq i64 %actual.tag, %tag" & vbCrLf
    Text = Text & "  %nominal.equal = icmp eq i64 %actual.nominal, %nominal" & vbCrLf
    Text = Text & "  %rank.equal = icmp eq i64 %actual.rank, %rank" & vbCrLf
    Text = Text & "  %cells.equal = icmp eq i64 %actual.cells, %cells" & vbCrLf
    Text = Text & "  %a = and i1 %tag.equal, %nominal.equal" & vbCrLf
    Text = Text & "  %b = and i1 %rank.equal, %cells.equal" & vbCrLf
    Text = Text & "  %equal = and i1 %a, %b" & vbCrLf
    Text = Text & "  br i1 %equal, label %done, label %mismatch" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "mismatch:" & vbCrLf
    Text = Text & "  store atomic i64 13, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Reference extraction preserves object identity; Empty has the neutral reference." & vbCrLf
    Text = Text & "define {i1,i64} @ube.variant.reference(ptr %ctx, i64 %identity, i64 %expected.nominal) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %valid = icmp ne ptr %data, null" & vbCrLf
    Text = Text & "  br i1 %valid, label %header, label %failed" & vbCrLf
    Text = Text & "header:" & vbCrLf
    Text = Text & "  %nominal.ptr = getelementptr i64, ptr %data, i64 -3" & vbCrLf
    Text = Text & "  %nominal = load i64, ptr %nominal.ptr, align 8" & vbCrLf
    Text = Text & "  %shape = call i1 @ube.variant.match(ptr %ctx, i64 %identity, i64 9, i64 %nominal, i64 0, i64 1)" & vbCrLf
    Text = Text & "  br i1 %shape, label %reference, label %failed" & vbCrLf
    Text = Text & "reference:" & vbCrLf
    Text = Text & "  %value = load i64, ptr %data, align 8" & vbCrLf
    Text = Text & "  %generic = icmp eq i64 %expected.nominal, 0" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %expected.nominal, %nominal" & vbCrLf
    Text = Text & "  %nothing = icmp eq i64 %value, 0" & vbCrLf
    Text = Text & "  %compatible = or i1 %generic, %same" & vbCrLf
    Text = Text & "  %accepted = or i1 %compatible, %nothing" & vbCrLf
    Text = Text & "  br i1 %accepted, label %done, label %mismatch" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %value, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "mismatch:" & vbCrLf
    Text = Text & "  store atomic i64 13, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 0}" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.variant.box(ptr %ctx, i64 %tag, i64 %value, ptr %layout, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %candidate = alloca i64, align 8" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %tag, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %create" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  call void @ube.managed.store(ptr %ctx, ptr %output, i64 0)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "create:" & vbCrLf
    Text = Text & "  %created = call i1 @ube.variant.create(ptr %ctx, i64 %tag, i64 0, i64 0, i64 1, ptr %layout, ptr null, ptr %candidate)" & vbCrLf
    Text = Text & "  br i1 %created, label %initialize, label %failed" & vbCrLf
    Text = Text & "initialize:" & vbCrLf
    Text = Text & "  %identity = load i64, ptr %candidate, align 8" & vbCrLf
    Text = Text & "  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  store i64 %value, ptr %data, align 8" & vbCrLf
    Text = Text & "  call void @ube.managed.publish.range(ptr %ctx, ptr %data, ptr %layout, i64 1)" & vbCrLf
    Text = Text & "  %published = call i1 @ube.variant.publish(ptr %ctx, ptr %output, i64 %identity)" & vbCrLf
    Text = Text & "  ret i1 %published" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedTextIR = Text
End Function

Private Function ManagedOwnersIR() As String
    Dim Text As String
    Text = Text & "; Only fresh private owners receive their immutable precise layout." & vbCrLf
    Text = Text & "define void @ube.managed.owner.layout(ptr %ctx, ptr %block, ptr %layout, i64 %count) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %present, label %attach, label %done" & vbCrLf
    Text = Text & "attach:" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4" & vbCrLf
    Text = Text & "  %managed = icmp ne ptr %layout, null" & vbCrLf
    Text = Text & "  %repeat = select i1 %managed, i64 %count, i64 0" & vbCrLf
    Text = Text & "  store ptr %layout, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %repeat, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; Retention alone does not root a native block; active leases publish this frame." & vbCrLf
    Text = Text & "define void @ube.managed.owner.root(ptr %ctx, ptr %frame, ptr %block) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %present, label %read, label %empty" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4" & vbCrLf
    Text = Text & "  %layout = load ptr, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  %count = load i64, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  %base = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  call void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr %base, ptr %layout, i64 %count)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  call void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr null, ptr null, i64 0)" & vbCrLf
    Text = Text & "  ret void" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedOwnersIR = Text
End Function

Private Function ManagedLayoutsIR() As String
    Dim Text As String
    Text = Text & "; Native-owner pointers are accepted only when present in this program's block registry." & vbCrLf
    Text = Text & "define internal i1 @ube.managed.block.valid(ptr %ctx, ptr %wanted) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %head = call ptr @ube.memory.head(ptr %ctx)" & vbCrLf
    Text = Text & "  %first = load ptr, ptr %head, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %block = phi ptr [ %first, %entry ], [ %next, %advance ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %absent" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %same = icmp eq ptr %block, %wanted" & vbCrLf
    Text = Text & "  br i1 %same, label %found, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %block, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "found:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "absent:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "; This bounded recursion decodes finite metadata, never follows managed identities." & vbCrLf
    Text = Text & "; Found=True returns one exact identity. Found=False returns the slot count, or -1 on error." & vbCrLf
    Text = Text & "define internal {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %base, ptr %layout, i64 %repeat, i64 %index, i64 %depth) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %repeat, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %validate" & vbCrLf
    Text = Text & "validate:" & vbCrLf
    Text = Text & "  %base.present = icmp ne ptr %base, null" & vbCrLf
    Text = Text & "  %layout.present = icmp ne ptr %layout, null" & vbCrLf
    Text = Text & "  %repeat.valid = icmp ule i64 %repeat, 2147483647" & vbCrLf
    Text = Text & "  %depth.valid = icmp ult i64 %depth, 66" & vbCrLf
    Text = Text & "  %pointers = and i1 %base.present, %layout.present" & vbCrLf
    Text = Text & "  %bounds = and i1 %repeat.valid, %depth.valid" & vbCrLf
    Text = Text & "  %valid = and i1 %pointers, %bounds" & vbCrLf
    Text = Text & "  br i1 %valid, label %metadata, label %bad" & vbCrLf
    Text = Text & "metadata:" & vbCrLf
    Text = Text & "  %stride.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 0" & vbCrLf
    Text = Text & "  %refs.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 1" & vbCrLf
    Text = Text & "  %offsets.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 2" & vbCrLf
    Text = Text & "  %arrays.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 3" & vbCrLf
    Text = Text & "  %entries.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 4" & vbCrLf
    Text = Text & "  %owners.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 5" & vbCrLf
    Text = Text & "  %owner.offsets.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 6" & vbCrLf
    Text = Text & "  %stride = load i64, ptr %stride.ptr, align 8" & vbCrLf
    Text = Text & "  %refs = load i64, ptr %refs.ptr, align 8" & vbCrLf
    Text = Text & "  %offsets = load ptr, ptr %offsets.ptr, align 8" & vbCrLf
    Text = Text & "  %arrays = load i64, ptr %arrays.ptr, align 8" & vbCrLf
    Text = Text & "  %entries = load ptr, ptr %entries.ptr, align 8" & vbCrLf
    Text = Text & "  %owners = load i64, ptr %owners.ptr, align 8" & vbCrLf
    Text = Text & "  %owner.offsets = load ptr, ptr %owner.offsets.ptr, align 8" & vbCrLf
    Text = Text & "  %stride.low = icmp sgt i64 %stride, 0" & vbCrLf
    Text = Text & "  %stride.high = icmp ule i64 %stride, 2147483647" & vbCrLf
    Text = Text & "  %refs.valid = icmp ule i64 %refs, 2147483647" & vbCrLf
    Text = Text & "  %arrays.valid = icmp ule i64 %arrays, 2147483647" & vbCrLf
    Text = Text & "  %owners.valid = icmp ule i64 %owners, 2147483647" & vbCrLf
    Text = Text & "  %s = and i1 %stride.low, %stride.high" & vbCrLf
    Text = Text & "  %a = and i1 %refs.valid, %arrays.valid" & vbCrLf
    Text = Text & "  %b = and i1 %a, %owners.valid" & vbCrLf
    Text = Text & "  %counts.valid = and i1 %s, %b" & vbCrLf
    Text = Text & "  %refs.empty = icmp eq i64 %refs, 0" & vbCrLf
    Text = Text & "  %refs.present = icmp ne ptr %offsets, null" & vbCrLf
    Text = Text & "  %refs.storage = or i1 %refs.empty, %refs.present" & vbCrLf
    Text = Text & "  %arrays.empty = icmp eq i64 %arrays, 0" & vbCrLf
    Text = Text & "  %arrays.present = icmp ne ptr %entries, null" & vbCrLf
    Text = Text & "  %arrays.storage = or i1 %arrays.empty, %arrays.present" & vbCrLf
    Text = Text & "  %owners.empty = icmp eq i64 %owners, 0" & vbCrLf
    Text = Text & "  %owners.present = icmp ne ptr %owner.offsets, null" & vbCrLf
    Text = Text & "  %owners.storage = or i1 %owners.empty, %owners.present" & vbCrLf
    Text = Text & "  %lists.first = and i1 %refs.storage, %arrays.storage" & vbCrLf
    Text = Text & "  %lists.valid = and i1 %lists.first, %owners.storage" & vbCrLf
    Text = Text & "  %shape = and i1 %counts.valid, %lists.valid" & vbCrLf
    Text = Text & "  br i1 %shape, label %offset.check, label %bad" & vbCrLf
    Text = Text & "offset.check:" & vbCrLf
    Text = Text & "  %direct = mul i64 %refs, %repeat" & vbCrLf
    Text = Text & "  %direct.valid = icmp ule i64 %direct, 2147483647" & vbCrLf
    Text = Text & "  br i1 %direct.valid, label %offset.loop, label %large" & vbCrLf
    Text = Text & "offset.loop:" & vbCrLf
    Text = Text & "  %offset.index = phi i64 [ 0, %offset.check ], [ %offset.next, %offset.read ]" & vbCrLf
    Text = Text & "  %has.offset = icmp ult i64 %offset.index, %refs" & vbCrLf
    Text = Text & "  br i1 %has.offset, label %offset.read, label %direct.check" & vbCrLf
    Text = Text & "offset.read:" & vbCrLf
    Text = Text & "  %offset.ptr = getelementptr i64, ptr %offsets, i64 %offset.index" & vbCrLf
    Text = Text & "  %offset = load i64, ptr %offset.ptr, align 8" & vbCrLf
    Text = Text & "  %offset.valid = icmp ult i64 %offset, %stride" & vbCrLf
    Text = Text & "  %offset.next = add i64 %offset.index, 1" & vbCrLf
    Text = Text & "  br i1 %offset.valid, label %offset.loop, label %bad" & vbCrLf
    Text = Text & "direct.check:" & vbCrLf
    Text = Text & "  %in.direct = icmp ult i64 %index, %direct" & vbCrLf
    Text = Text & "  br i1 %in.direct, label %direct.read, label %children" & vbCrLf
    Text = Text & "direct.read:" & vbCrLf
    Text = Text & "  %element = udiv i64 %index, %refs" & vbCrLf
    Text = Text & "  %reference = urem i64 %index, %refs" & vbCrLf
    Text = Text & "  %reference.ptr = getelementptr i64, ptr %offsets, i64 %reference" & vbCrLf
    Text = Text & "  %reference.offset = load i64, ptr %reference.ptr, align 8" & vbCrLf
    Text = Text & "  %element.offset = mul i64 %element, %stride" & vbCrLf
    Text = Text & "  %cell.offset = add i64 %element.offset, %reference.offset" & vbCrLf
    Text = Text & "  %cell = getelementptr i64, ptr %base, i64 %cell.offset" & vbCrLf
    Text = Text & "  %identity = load atomic i64, ptr %cell acquire, align 8" & vbCrLf
    Text = Text & "  %direct.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %identity, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %direct.result" & vbCrLf
    Text = Text & "children:" & vbCrLf
    Text = Text & "  %child.count = add i64 %arrays, %owners" & vbCrLf
    Text = Text & "  %has.children = icmp ne i64 %child.count, 0" & vbCrLf
    Text = Text & "  %counting = icmp slt i64 %index, 0" & vbCrLf
    Text = Text & "  %remaining.direct = sub i64 %index, %direct" & vbCrLf
    Text = Text & "  %initial.index = select i1 %counting, i64 -1, i64 %remaining.direct" & vbCrLf
    Text = Text & "  br i1 %has.children, label %child.loop, label %direct.count" & vbCrLf
    Text = Text & "child.loop:" & vbCrLf
    Text = Text & "  %row = phi i64 [ 0, %children ], [ %next.row, %advance ]" & vbCrLf
    Text = Text & "  %child.index = phi i64 [ 0, %children ], [ %next.child, %advance ]" & vbCrLf
    Text = Text & "  %remaining = phi i64 [ %initial.index, %children ], [ %next.remaining, %advance ]" & vbCrLf
    Text = Text & "  %total = phi i64 [ %direct, %children ], [ %new.total, %advance ]" & vbCrLf
    Text = Text & "  %row.offset = mul i64 %row, %stride" & vbCrLf
    Text = Text & "  %row.base = getelementptr i64, ptr %base, i64 %row.offset" & vbCrLf
    Text = Text & "  %is.array = icmp ult i64 %child.index, %arrays" & vbCrLf
    Text = Text & "  br i1 %is.array, label %array, label %owner" & vbCrLf
    Text = Text & "array:" & vbCrLf
    Text = Text & "  %entry.ptr = getelementptr %ube.managed.array, ptr %entries, i64 %child.index" & vbCrLf
    Text = Text & "  %descriptor.offset = load i64, ptr %entry.ptr, align 8" & vbCrLf
    Text = Text & "  %array.layout.ptr = getelementptr %ube.managed.array, ptr %entry.ptr, i32 0, i32 1" & vbCrLf
    Text = Text & "  %array.layout = load ptr, ptr %array.layout.ptr, align 8" & vbCrLf
    Text = Text & "  %descriptor.end = add i64 %descriptor.offset, 4" & vbCrLf
    Text = Text & "  %descriptor.in = icmp ule i64 %descriptor.end, %stride" & vbCrLf
    Text = Text & "  %descriptor.nonnegative = icmp sge i64 %descriptor.offset, 0" & vbCrLf
    Text = Text & "  %descriptor.valid = and i1 %descriptor.in, %descriptor.nonnegative" & vbCrLf
    Text = Text & "  br i1 %descriptor.valid, label %array.read, label %bad" & vbCrLf
    Text = Text & "array.read:" & vbCrLf
    Text = Text & "  %descriptor = getelementptr i64, ptr %row.base, i64 %descriptor.offset" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %descriptor, i64 1" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %descriptor, i64 2" & vbCrLf
    Text = Text & "  %lower = load i64, ptr %descriptor, align 8" & vbCrLf
    Text = Text & "  %upper = load i64, ptr %upper.ptr, align 8" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %nonempty = icmp sge i64 %upper, %lower" & vbCrLf
    Text = Text & "  %difference = sub i64 %upper, %lower" & vbCrLf
    Text = Text & "  %length = add i64 %difference, 1" & vbCrLf
    Text = Text & "  %array.count = select i1 %nonempty, i64 %length, i64 0" & vbCrLf
    Text = Text & "  %array.extent = icmp ule i64 %array.count, 2147483647" & vbCrLf
    Text = Text & "  %lower.valid = icmp sge i64 %lower, -2147483648" & vbCrLf
    Text = Text & "  %upper.valid = icmp sle i64 %upper, 2147483647" & vbCrLf
    Text = Text & "  %bounds.valid = and i1 %lower.valid, %upper.valid" & vbCrLf
    Text = Text & "  %array.valid = and i1 %array.extent, %bounds.valid" & vbCrLf
    Text = Text & "  br i1 %array.valid, label %visit.array, label %bad" & vbCrLf
    Text = Text & "visit.array:" & vbCrLf
    Text = Text & "  br label %visit" & vbCrLf
    Text = Text & "owner:" & vbCrLf
    Text = Text & "  %owner.index = sub i64 %child.index, %arrays" & vbCrLf
    Text = Text & "  %owner.offset.ptr = getelementptr i64, ptr %owner.offsets, i64 %owner.index" & vbCrLf
    Text = Text & "  %owner.offset = load i64, ptr %owner.offset.ptr, align 8" & vbCrLf
    Text = Text & "  %owner.in = icmp ult i64 %owner.offset, %stride" & vbCrLf
    Text = Text & "  br i1 %owner.in, label %owner.read, label %bad" & vbCrLf
    Text = Text & "owner.read:" & vbCrLf
    Text = Text & "  %owner.slot = getelementptr i64, ptr %row.base, i64 %owner.offset" & vbCrLf
    Text = Text & "  %block = load ptr, ptr %owner.slot, align 8" & vbCrLf
    Text = Text & "  %owner.present = icmp ne ptr %block, null" & vbCrLf
    Text = Text & "  br i1 %owner.present, label %owner.validate, label %empty.owner" & vbCrLf
    Text = Text & "owner.validate:" & vbCrLf
    Text = Text & "  %registered = call i1 @ube.managed.block.valid(ptr %ctx, ptr %block)" & vbCrLf
    Text = Text & "  br i1 %registered, label %owner.layout, label %bad" & vbCrLf
    Text = Text & "owner.layout:" & vbCrLf
    Text = Text & "  %block.layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3" & vbCrLf
    Text = Text & "  %block.count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4" & vbCrLf
    Text = Text & "  %block.layout = load ptr, ptr %block.layout.ptr, align 8" & vbCrLf
    Text = Text & "  %block.count = load i64, ptr %block.count.ptr, align 8" & vbCrLf
    Text = Text & "  %block.data = getelementptr %ube.block, ptr %block, i64 1" & vbCrLf
    Text = Text & "  br label %visit" & vbCrLf
    Text = Text & "empty.owner:" & vbCrLf
    Text = Text & "  br label %visit" & vbCrLf
    Text = Text & "visit:" & vbCrLf
    Text = Text & "  %child.base = phi ptr [ %data, %visit.array ], [ %block.data, %owner.layout ], [ null, %empty.owner ]" & vbCrLf
    Text = Text & "  %child.layout = phi ptr [ %array.layout, %visit.array ], [ %block.layout, %owner.layout ], [ null, %empty.owner ]" & vbCrLf
    Text = Text & "  %child.repeat = phi i64 [ %array.count, %visit.array ], [ %block.count, %owner.layout ], [ 0, %empty.owner ]" & vbCrLf
    Text = Text & "  %next.depth = add i64 %depth, 1" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %child.base, ptr %child.layout, i64 %child.repeat, i64 %remaining, i64 %next.depth)" & vbCrLf
    Text = Text & "  %found = extractvalue {i1,i64} %result, 0" & vbCrLf
    Text = Text & "  %value = extractvalue {i1,i64} %result, 1" & vbCrLf
    Text = Text & "  br i1 %found, label %return.found, label %count.child" & vbCrLf
    Text = Text & "return.found:" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "count.child:" & vbCrLf
    Text = Text & "  %child.ok = icmp sge i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %child.ok, label %sum, label %error" & vbCrLf
    Text = Text & "sum:" & vbCrLf
    Text = Text & "  %new.total = add i64 %total, %value" & vbCrLf
    Text = Text & "  %total.valid = icmp ule i64 %new.total, 2147483647" & vbCrLf
    Text = Text & "  br i1 %total.valid, label %advance, label %large" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %remaining.child = sub i64 %remaining, %value" & vbCrLf
    Text = Text & "  %next.remaining = select i1 %counting, i64 -1, i64 %remaining.child" & vbCrLf
    Text = Text & "  %increment.child = add i64 %child.index, 1" & vbCrLf
    Text = Text & "  %last.child = icmp eq i64 %increment.child, %child.count" & vbCrLf
    Text = Text & "  %next.child = select i1 %last.child, i64 0, i64 %increment.child" & vbCrLf
    Text = Text & "  %increment.row = add i64 %row, 1" & vbCrLf
    Text = Text & "  %next.row = select i1 %last.child, i64 %increment.row, i64 %row" & vbCrLf
    Text = Text & "  %more.rows = icmp ult i64 %next.row, %repeat" & vbCrLf
    Text = Text & "  br i1 %more.rows, label %child.loop, label %children.count" & vbCrLf
    Text = Text & "children.count:" & vbCrLf
    Text = Text & "  %child.result = insertvalue {i1,i64} zeroinitializer, i64 %new.total, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %child.result" & vbCrLf
    Text = Text & "direct.count:" & vbCrLf
    Text = Text & "  %count.result = insertvalue {i1,i64} zeroinitializer, i64 %direct, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %count.result" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  ret {i1,i64} zeroinitializer" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %error" & vbCrLf
    Text = Text & "large:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %error" & vbCrLf
    Text = Text & "error:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 -1}" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedLayoutsIR = Text
End Function

Private Function ManagedRootsIR() As String
    Dim Text As String
    Text = Text & "; Enumerates published typed roots only; integers and native handles are excluded." & vbCrLf
    Text = Text & "define internal {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 %index) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %remaining.ptr = alloca i64, align 8" & vbCrLf
    Text = Text & "  %total.ptr = alloca i64, align 8" & vbCrLf
    Text = Text & "  store i64 %index, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %counting = icmp slt i64 %index, 0" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15" & vbCrLf
    Text = Text & "  %first = load ptr, ptr %head, align 8" & vbCrLf
    Text = Text & "  br label %threads" & vbCrLf
    Text = Text & "threads:" & vbCrLf
    Text = Text & "  %thread = phi ptr [ %first, %entry ], [ %next.thread, %advance.thread ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %thread, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %handoff, label %done" & vbCrLf
    Text = Text & "handoff:" & vbCrLf
    Text = Text & "  %handoff.slot = getelementptr %ube.thread, ptr %thread, i32 0, i32 8" & vbCrLf
    Text = Text & "  %handoff.index = load i64, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %at.handoff = icmp eq i64 %handoff.index, 0" & vbCrLf
    Text = Text & "  br i1 %at.handoff, label %return.handoff, label %count.handoff" & vbCrLf
    Text = Text & "return.handoff:" & vbCrLf
    Text = Text & "  %handoff.value = load atomic i64, ptr %handoff.slot acquire, align 8" & vbCrLf
    Text = Text & "  %handoff.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %handoff.value, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %handoff.result" & vbCrLf
    Text = Text & "count.handoff:" & vbCrLf
    Text = Text & "  %handoff.total = load i64, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %with.handoff = add i64 %handoff.total, 1" & vbCrLf
    Text = Text & "  store i64 %with.handoff, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %less.handoff = sub i64 %handoff.index, 1" & vbCrLf
    Text = Text & "  %after.handoff = select i1 %counting, i64 -1, i64 %less.handoff" & vbCrLf
    Text = Text & "  store i64 %after.handoff, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %candidates = getelementptr %ube.thread, ptr %thread, i32 0, i32 5" & vbCrLf
    Text = Text & "  %first.candidate = load ptr, ptr %candidates, align 8" & vbCrLf
    Text = Text & "  br label %candidate.loop" & vbCrLf
    Text = Text & "candidate.loop:" & vbCrLf
    Text = Text & "  %candidate = phi ptr [ %first.candidate, %count.handoff ], [ %next.candidate, %count.candidate ]" & vbCrLf
    Text = Text & "  %candidate.exists = icmp ne ptr %candidate, null" & vbCrLf
    Text = Text & "  br i1 %candidate.exists, label %candidate.read, label %frame.start" & vbCrLf
    Text = Text & "candidate.read:" & vbCrLf
    Text = Text & "  %candidate.index = load i64, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %at.candidate = icmp eq i64 %candidate.index, 0" & vbCrLf
    Text = Text & "  br i1 %at.candidate, label %return.candidate, label %count.candidate" & vbCrLf
    Text = Text & "return.candidate:" & vbCrLf
    Text = Text & "  %candidate.id.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 1" & vbCrLf
    Text = Text & "  %candidate.id = load i64, ptr %candidate.id.ptr, align 8" & vbCrLf
    Text = Text & "  %candidate.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %candidate.id, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %candidate.result" & vbCrLf
    Text = Text & "count.candidate:" & vbCrLf
    Text = Text & "  %candidate.total = load i64, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %with.candidate = add i64 %candidate.total, 1" & vbCrLf
    Text = Text & "  store i64 %with.candidate, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %less.candidate = sub i64 %candidate.index, 1" & vbCrLf
    Text = Text & "  %after.candidate = select i1 %counting, i64 -1, i64 %less.candidate" & vbCrLf
    Text = Text & "  store i64 %after.candidate, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %candidate.next.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 4" & vbCrLf
    Text = Text & "  %next.candidate = load ptr, ptr %candidate.next.ptr, align 8" & vbCrLf
    Text = Text & "  br label %candidate.loop" & vbCrLf
    Text = Text & "frame.start:" & vbCrLf
    Text = Text & "  %frame.head = getelementptr %ube.thread, ptr %thread, i32 0, i32 4" & vbCrLf
    Text = Text & "  %first.frame = load atomic ptr, ptr %frame.head acquire, align 8" & vbCrLf
    Text = Text & "  br label %frames" & vbCrLf
    Text = Text & "frames:" & vbCrLf
    Text = Text & "  %frame = phi ptr [ %first.frame, %frame.start ], [ %next.frame, %advance.frame ]" & vbCrLf
    Text = Text & "  %frame.exists = icmp ne ptr %frame, null" & vbCrLf
    Text = Text & "  br i1 %frame.exists, label %frame.read, label %advance.thread" & vbCrLf
    Text = Text & "frame.read:" & vbCrLf
    Text = Text & "  %base.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 1" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 2" & vbCrLf
    Text = Text & "  %repeat.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 3" & vbCrLf
    Text = Text & "  %base = load ptr, ptr %base.ptr, align 8" & vbCrLf
    Text = Text & "  %layout = load ptr, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  %repeat = load i64, ptr %repeat.ptr, align 8" & vbCrLf
    Text = Text & "  %frame.index = load i64, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %base, ptr %layout, i64 %repeat, i64 %frame.index, i64 0)" & vbCrLf
    Text = Text & "  %found = extractvalue {i1,i64} %result, 0" & vbCrLf
    Text = Text & "  %value = extractvalue {i1,i64} %result, 1" & vbCrLf
    Text = Text & "  br i1 %found, label %return.frame, label %count.frame" & vbCrLf
    Text = Text & "return.frame:" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "count.frame:" & vbCrLf
    Text = Text & "  %frame.ok = icmp sge i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %frame.ok, label %sum.frame, label %error" & vbCrLf
    Text = Text & "sum.frame:" & vbCrLf
    Text = Text & "  %frame.total = load i64, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %with.frame = add i64 %frame.total, %value" & vbCrLf
    Text = Text & "  %total.valid = icmp ule i64 %with.frame, 2147483647" & vbCrLf
    Text = Text & "  br i1 %total.valid, label %advance.frame, label %large" & vbCrLf
    Text = Text & "advance.frame:" & vbCrLf
    Text = Text & "  store i64 %with.frame, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %less.frame = sub i64 %frame.index, %value" & vbCrLf
    Text = Text & "  %after.frame = select i1 %counting, i64 -1, i64 %less.frame" & vbCrLf
    Text = Text & "  store i64 %after.frame, ptr %remaining.ptr, align 8" & vbCrLf
    Text = Text & "  %next.frame = load ptr, ptr %frame, align 8" & vbCrLf
    Text = Text & "  br label %frames" & vbCrLf
    Text = Text & "advance.thread:" & vbCrLf
    Text = Text & "  %next.thread.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 6" & vbCrLf
    Text = Text & "  %next.thread = load ptr, ptr %next.thread.ptr, align 8" & vbCrLf
    Text = Text & "  br label %threads" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  %total = load i64, ptr %total.ptr, align 8" & vbCrLf
    Text = Text & "  %answer = insertvalue {i1,i64} zeroinitializer, i64 %total, 1" & vbCrLf
    Text = Text & "  ret {i1,i64} %answer" & vbCrLf
    Text = Text & "large:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %error" & vbCrLf
    Text = Text & "error:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 -1}" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.root.at(ptr %ctx, i64 %index, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %bounds, label %failed" & vbCrLf
    Text = Text & "bounds:" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9" & vbCrLf
    Text = Text & "  %count = load i64, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %index, %count" & vbCrLf
    Text = Text & "  br i1 %valid, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 %index)" & vbCrLf
    Text = Text & "  %found = extractvalue {i1,i64} %result, 0" & vbCrLf
    Text = Text & "  %value = extractvalue {i1,i64} %result, 1" & vbCrLf
    Text = Text & "  br i1 %found, label %publish, label %failed" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store i64 %value, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define internal {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 %index) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %empty, label %failed" & vbCrLf
    Text = Text & "empty:" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %none, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7" & vbCrLf
    Text = Text & "  %repeat.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %layout = load ptr, ptr %layout.ptr, align 8" & vbCrLf
    Text = Text & "  %repeat = load i64, ptr %repeat.ptr, align 8" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %data, ptr %layout, i64 %repeat, i64 %index, i64 0)" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "none:" & vbCrLf
    Text = Text & "  ret {i1,i64} zeroinitializer" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 false,i64 -1}" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.edge.count(ptr %ctx, i64 %identity, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 -1)" & vbCrLf
    Text = Text & "  %count = extractvalue {i1,i64} %result, 1" & vbCrLf
    Text = Text & "  %valid = icmp sge i64 %count, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %publish, label %failed" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store i64 %count, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.edge.at(ptr %ctx, i64 %identity, i64 %index, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %valid = icmp sge i64 %index, 0" & vbCrLf
    Text = Text & "  br i1 %valid, label %read, label %bad" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %result = call {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 %index)" & vbCrLf
    Text = Text & "  %found = extractvalue {i1,i64} %result, 0" & vbCrLf
    Text = Text & "  %value = extractvalue {i1,i64} %result, 1" & vbCrLf
    Text = Text & "  br i1 %found, label %publish, label %not.found" & vbCrLf
    Text = Text & "not.found:" & vbCrLf
    Text = Text & "  %error = icmp slt i64 %value, 0" & vbCrLf
    Text = Text & "  br i1 %error, label %failed, label %bad" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  store i64 %value, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedRootsIR = Text
End Function

Private Function ManagedCollectionIR() As String
    Dim Text As String
    Text = Text & "; Begin owns or joins one synchronous round; completed results remain until joiners consume them." & vbCrLf
    Text = Text & "define i1 @ube.managed.begin(ptr %ctx, ptr %prior.work, ptr %prior.error) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %setup, label %invalid" & vbCrLf
    Text = Text & "setup:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %work.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 5" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6" & vbCrLf
    Text = Text & "  %allocation.count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %root.count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9" & vbCrLf
    Text = Text & "  %joiners.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 12" & vbCrLf
    Text = Text & "  %status.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7" & vbCrLf
    Text = Text & "  br label %elect" & vbCrLf
    Text = Text & "elect:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %request = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %active = icmp ne i64 %request, 0" & vbCrLf
    Text = Text & "  br i1 %active, label %join.check, label %admit" & vbCrLf
    Text = Text & "join.check:" & vbCrLf
    Text = Text & "  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %recursive = icmp eq ptr %owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %recursive, label %recursive.error, label %join" & vbCrLf
    Text = Text & "recursive.error:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %invalid" & vbCrLf
    Text = Text & "join:" & vbCrLf
    Text = Text & "  %joiners = load i64, ptr %joiners.ptr, align 8" & vbCrLf
    Text = Text & "  %more.joiners = add i64 %joiners, 1" & vbCrLf
    Text = Text & "  store i64 %more.joiners, ptr %joiners.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %status.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %join.wait" & vbCrLf
    Text = Text & "join.wait:" & vbCrLf
    Text = Text & "  %joining = load atomic i64, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %joined = icmp eq i64 %joining, 0" & vbCrLf
    Text = Text & "  br i1 %joined, label %join.result, label %join.yield" & vbCrLf
    Text = Text & "join.yield:" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %join.wait" & vbCrLf
    Text = Text & "join.result:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %joined.work = load i64, ptr %work.ptr, align 8" & vbCrLf
    Text = Text & "  %joined.error = load i64, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %joined.work, ptr %prior.work, align 8" & vbCrLf
    Text = Text & "  store i64 %joined.error, ptr %prior.error, align 8" & vbCrLf
    Text = Text & "  %remaining.joiners = load i64, ptr %joiners.ptr, align 8" & vbCrLf
    Text = Text & "  %less.joiners = sub i64 %remaining.joiners, 1" & vbCrLf
    Text = Text & "  store i64 %less.joiners, ptr %joiners.ptr, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @ube.managed.enter(ptr %ctx)" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "admit:" & vbCrLf
    Text = Text & "  %waiting.joiners = load i64, ptr %joiners.ptr, align 8" & vbCrLf
    Text = Text & "  %readers.done = icmp eq i64 %waiting.joiners, 0" & vbCrLf
    Text = Text & "  br i1 %readers.done, label %own, label %admit.wait" & vbCrLf
    Text = Text & "admit.wait:" & vbCrLf
    Text = Text & "  store atomic i64 2, ptr %status.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %elect" & vbCrLf
    Text = Text & "own:" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %status.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %ctx, ptr %owner.ptr release, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %work.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 1, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %rendezvous" & vbCrLf
    Text = Text & "rendezvous:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %thread.head = getelementptr %ube.program, ptr %program, i32 0, i32 15" & vbCrLf
    Text = Text & "  %first.thread = load ptr, ptr %thread.head, align 8" & vbCrLf
    Text = Text & "  br label %threads" & vbCrLf
    Text = Text & "threads:" & vbCrLf
    Text = Text & "  %thread = phi ptr [ %first.thread, %rendezvous ], [ %next.thread, %advance ]" & vbCrLf
    Text = Text & "  %thread.exists = icmp ne ptr %thread, null" & vbCrLf
    Text = Text & "  br i1 %thread.exists, label %inspect, label %stopped" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %thread, %ctx" & vbCrLf
    Text = Text & "  br i1 %mine, label %advance, label %inspect.status" & vbCrLf
    Text = Text & "inspect.status:" & vbCrLf
    Text = Text & "  %thread.status.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 7" & vbCrLf
    Text = Text & "  %thread.status = load atomic i64, ptr %thread.status.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  %running = icmp eq i64 %thread.status, 0" & vbCrLf
    Text = Text & "  br i1 %running, label %wait, label %advance" & vbCrLf
    Text = Text & "advance:" & vbCrLf
    Text = Text & "  %next.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 6" & vbCrLf
    Text = Text & "  %next.thread = load ptr, ptr %next.ptr, align 8" & vbCrLf
    Text = Text & "  br label %threads" & vbCrLf
    Text = Text & "wait:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @Sleep(i32 0)" & vbCrLf
    Text = Text & "  br label %rendezvous" & vbCrLf
    Text = Text & "stopped:" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %retired = call i1 @ube.memory.collect.locked(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  store i64 0, ptr %prior.work, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %prior.error, align 8" & vbCrLf
    Text = Text & "  %first.record = load atomic ptr, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  br label %snapshot" & vbCrLf
    Text = Text & "snapshot:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first.record, %stopped ], [ %next.record, %record.read ]" & vbCrLf
    Text = Text & "  %allocation.count = phi i64 [ 0, %stopped ], [ %next.count, %record.read ]" & vbCrLf
    Text = Text & "  %record.exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %record.exists, label %capacity, label %roots" & vbCrLf
    Text = Text & "capacity:" & vbCrLf
    Text = Text & "  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16" & vbCrLf
    Text = Text & "  %capacity.value = load i64, ptr %capacity.ptr, align 8" & vbCrLf
    Text = Text & "  %room = icmp ult i64 %allocation.count, %capacity.value" & vbCrLf
    Text = Text & "  br i1 %room, label %record.read, label %metadata.error" & vbCrLf
    Text = Text & "record.read:" & vbCrLf
    Text = Text & "  %identity.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1" & vbCrLf
    Text = Text & "  %identity = load i64, ptr %identity.ptr, align 8" & vbCrLf
    Text = Text & "  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10" & vbCrLf
    Text = Text & "  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8" & vbCrLf
    Text = Text & "  %slot = getelementptr i64, ptr %snapshot.data, i64 %allocation.count" & vbCrLf
    Text = Text & "  store i64 %identity, ptr %slot, align 8" & vbCrLf
    Text = Text & "  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  store i64 0, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  %next.record = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  %next.count = add i64 %allocation.count, 1" & vbCrLf
    Text = Text & "  br label %snapshot" & vbCrLf
    Text = Text & "roots:" & vbCrLf
    Text = Text & "  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17" & vbCrLf
    Text = Text & "  %live = load i64, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %consistent = icmp eq i64 %allocation.count, %live" & vbCrLf
    Text = Text & "  br i1 %consistent, label %counts, label %metadata.error" & vbCrLf
    Text = Text & "counts:" & vbCrLf
    Text = Text & "  store i64 %allocation.count, ptr %allocation.count.ptr, align 8" & vbCrLf
    Text = Text & "  %root.result = call {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 -1)" & vbCrLf
    Text = Text & "  %root.count = extractvalue {i1,i64} %root.result, 1" & vbCrLf
    Text = Text & "  %roots.valid = icmp sge i64 %root.count, 0" & vbCrLf
    Text = Text & "  br i1 %roots.valid, label %ready, label %root.error" & vbCrLf
    Text = Text & "ready:" & vbCrLf
    Text = Text & "  store i64 %root.count, ptr %root.count.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 1, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "metadata.error:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %root.error" & vbCrLf
    Text = Text & "root.error:" & vbCrLf
    Text = Text & "  %failure = load atomic i64, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  store i64 %failure, ptr %prior.error, align 8" & vbCrLf
    Text = Text & "  store i64 %failure, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 -1, ptr %root.count.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "invalid:" & vbCrLf
    Text = Text & "  store i64 0, ptr %prior.work, align 8" & vbCrLf
    Text = Text & "  store i64 5, ptr %prior.error, align 8" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.managed.end(ptr %ctx, i64 %work, i64 %error) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %start, label %failed" & vbCrLf
    Text = Text & "start:" & vbCrLf
    Text = Text & "  %first = load atomic ptr, ptr %state acquire, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "scan:" & vbCrLf
    Text = Text & "  %record = phi ptr [ %first, %start ], [ %next, %clear ]" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %clear, label %publish" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  store i64 0, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  %next = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  br label %scan" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.lock(ptr %program)" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %work.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 5" & vbCrLf
    Text = Text & "  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6" & vbCrLf
    Text = Text & "  %epoch.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 7" & vbCrLf
    Text = Text & "  %epoch = load i64, ptr %epoch.ptr, align 8" & vbCrLf
    Text = Text & "  %next.epoch = add i64 %epoch, 1" & vbCrLf
    Text = Text & "  store i64 %next.epoch, ptr %epoch.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %work, ptr %work.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %error, ptr %error.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic ptr null, ptr %owner.ptr release, align 8" & vbCrLf
    Text = Text & "  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14" & vbCrLf
    Text = Text & "  store ptr null, ptr %lease.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %request.ptr seq_cst, align 8" & vbCrLf
    Text = Text & "  call void @ube.thread.registry.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedCollectionIR = Text
End Function

Private Function ManagedReclamationIR() As String
    Dim Text As String
    Text = Text & "; The ordinary UBE collector has already selected this unmarked identity after sealing." & vbCrLf
    Text = Text & "define i1 @ube.managed.reclaim(ptr %ctx, i64 %identity) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %phase, label %failed" & vbCrLf
    Text = Text & "phase:" & vbCrLf
    Text = Text & "  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4" & vbCrLf
    Text = Text & "  %phase.value = load i64, ptr %phase.ptr, align 8" & vbCrLf
    Text = Text & "  %sealed = icmp eq i64 %phase.value, 2" & vbCrLf
    Text = Text & "  br i1 %sealed, label %find, label %bad" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %inspect, label %bad" & vbCrLf
    Text = Text & "inspect:" & vbCrLf
    Text = Text & "  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3" & vbCrLf
    Text = Text & "  %mark = load i64, ptr %mark.ptr, align 8" & vbCrLf
    Text = Text & "  %owner = load ptr, ptr %owner.ptr, align 8" & vbCrLf
    Text = Text & "  %unmarked = icmp eq i64 %mark, 0" & vbCrLf
    Text = Text & "  %published = icmp eq ptr %owner, null" & vbCrLf
    Text = Text & "  %eligible = and i1 %unmarked, %published" & vbCrLf
    Text = Text & "  br i1 %eligible, label %cleanup, label %bad" & vbCrLf
    Text = Text & "cleanup:" & vbCrLf
    Text = Text & "  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12" & vbCrLf
    Text = Text & "  %cleanup.function = load ptr, ptr %cleanup.ptr, align 8" & vbCrLf
    Text = Text & "  %has.cleanup = icmp ne ptr %cleanup.function, null" & vbCrLf
    Text = Text & "  br i1 %has.cleanup, label %retire.payload, label %lock" & vbCrLf
    Text = Text & "retire.payload:" & vbCrLf
    Text = Text & "; Retire native owners once, before taking storage locks; failed OS release may retry." & vbCrLf
    Text = Text & "  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %payload = load ptr, ptr %payload.ptr, align 8" & vbCrLf
    Text = Text & "  call void %cleanup.function(ptr %ctx, ptr %payload)" & vbCrLf
    Text = Text & "  store ptr null, ptr %cleanup.ptr, align 8" & vbCrLf
    Text = Text & "  br label %lock" & vbCrLf
    Text = Text & "lock:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %block = getelementptr %ube.block, ptr %record, i64 -1" & vbCrLf
    Text = Text & "  %native.head = call ptr @ube.memory.head(ptr %ctx)" & vbCrLf
    Text = Text & "  br label %native.scan" & vbCrLf
    Text = Text & "native.scan:" & vbCrLf
    Text = Text & "  %native.link = phi ptr [ %native.head, %lock ], [ %native.item, %native.advance ]" & vbCrLf
    Text = Text & "  %native.item = load ptr, ptr %native.link, align 8" & vbCrLf
    Text = Text & "  %native.exists = icmp ne ptr %native.item, null" & vbCrLf
    Text = Text & "  br i1 %native.exists, label %native.inspect, label %locked.bad" & vbCrLf
    Text = Text & "native.inspect:" & vbCrLf
    Text = Text & "  %native.same = icmp eq ptr %native.item, %block" & vbCrLf
    Text = Text & "  br i1 %native.same, label %managed.start, label %native.advance" & vbCrLf
    Text = Text & "native.advance:" & vbCrLf
    Text = Text & "  br label %native.scan" & vbCrLf
    Text = Text & "managed.start:" & vbCrLf
    Text = Text & "  br label %managed.scan" & vbCrLf
    Text = Text & "managed.scan:" & vbCrLf
    Text = Text & "  %managed.link = phi ptr [ %state, %managed.start ], [ %managed.item, %managed.advance ]" & vbCrLf
    Text = Text & "  %managed.item = load ptr, ptr %managed.link, align 8" & vbCrLf
    Text = Text & "  %managed.exists = icmp ne ptr %managed.item, null" & vbCrLf
    Text = Text & "  br i1 %managed.exists, label %managed.inspect, label %locked.bad" & vbCrLf
    Text = Text & "managed.inspect:" & vbCrLf
    Text = Text & "  %managed.same = icmp eq ptr %managed.item, %record" & vbCrLf
    Text = Text & "  br i1 %managed.same, label %release, label %managed.advance" & vbCrLf
    Text = Text & "managed.advance:" & vbCrLf
    Text = Text & "  br label %managed.scan" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  %next.native = load ptr, ptr %block, align 8" & vbCrLf
    Text = Text & "  %next.managed = load ptr, ptr %record, align 8" & vbCrLf
    Text = Text & "  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2" & vbCrLf
    Text = Text & "  %charge = load atomic i64, ptr %charge.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %released = call i1 @ube.target.release(ptr %block)" & vbCrLf
    Text = Text & "  br i1 %released, label %unlink, label %retained" & vbCrLf
    Text = Text & "unlink:" & vbCrLf
    Text = Text & "  store ptr %next.native, ptr %native.link, align 8" & vbCrLf
    Text = Text & "  store atomic ptr %next.managed, ptr %managed.link release, align 8" & vbCrLf
    Text = Text & "  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17" & vbCrLf
    Text = Text & "  %live = load i64, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %less.live = sub i64 %live, 1" & vbCrLf
    Text = Text & "  store i64 %less.live, ptr %live.ptr, align 8" & vbCrLf
    Text = Text & "  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)" & vbCrLf
    Text = Text & "  %blocks.ptr = call ptr @ube.memory.count(ptr %ctx)" & vbCrLf
    Text = Text & "  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %blocks = load atomic i64, ptr %blocks.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %less.bytes = sub i64 %bytes, %charge" & vbCrLf
    Text = Text & "  %less.blocks = sub i64 %blocks, 1" & vbCrLf
    Text = Text & "  store atomic i64 %less.bytes, ptr %bytes.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  store atomic i64 %less.blocks, ptr %blocks.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8" & vbCrLf
    Text = Text & "  %count = load i64, ptr %count.ptr, align 8" & vbCrLf
    Text = Text & "  br label %snapshot" & vbCrLf
    Text = Text & "snapshot:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %unlink ], [ %next.index, %slot ]" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %index, %count" & vbCrLf
    Text = Text & "  br i1 %more, label %slot, label %done" & vbCrLf
    Text = Text & "slot:" & vbCrLf
    Text = Text & "  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10" & vbCrLf
    Text = Text & "  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8" & vbCrLf
    Text = Text & "  %slot.ptr = getelementptr i64, ptr %snapshot.data, i64 %index" & vbCrLf
    Text = Text & "  %slot.value = load i64, ptr %slot.ptr, align 8" & vbCrLf
    Text = Text & "  %same = icmp eq i64 %slot.value, %identity" & vbCrLf
    Text = Text & "  %new.value = select i1 %same, i64 0, i64 %slot.value" & vbCrLf
    Text = Text & "  store i64 %new.value, ptr %slot.ptr, align 8" & vbCrLf
    Text = Text & "  %next.index = add i64 %index, 1" & vbCrLf
    Text = Text & "  br label %snapshot" & vbCrLf
    Text = Text & "retained:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  store atomic i64 57, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "locked.bad:" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  br label %bad" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedReclamationIR = Text
End Function

Private Function ManagedCallbackIR() As String
    Dim Text As String
    Text = Text & "; The linked UBE callback runs with independent bounded support call depth." & vbCrLf
    Text = Text & "define {i1,i64} @ube.managed.collect(ptr %ctx, i64 %report) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %incoming.error = load atomic i64, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1" & vbCrLf
    Text = Text & "  %incoming.depth = load atomic i64, ptr %depth.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.state(ptr %ctx)" & vbCrLf
    Text = Text & "  %present = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %present, label %owner, label %native" & vbCrLf
    Text = Text & "native:" & vbCrLf
    Text = Text & "  %program = call ptr @ube.thread.program(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.lock(ptr %program)" & vbCrLf
    Text = Text & "  %retired = call i1 @ube.memory.collect.locked(ptr %ctx)" & vbCrLf
    Text = Text & "  call void @ube.program.storage.unlock(ptr %program)" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "owner:" & vbCrLf
    Text = Text & "  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2" & vbCrLf
    Text = Text & "  %coordinator = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %recursive = icmp eq ptr %coordinator, %ctx" & vbCrLf
    Text = Text & "  br i1 %recursive, label %suppressed, label %callback" & vbCrLf
    Text = Text & "callback:" & vbCrLf
    Text = Text & "  %callback.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 1" & vbCrLf
    Text = Text & "  %procedure = load ptr, ptr %callback.ptr, align 8" & vbCrLf
    Text = Text & "  store atomic i64 0, ptr %depth.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %result = call {i1,i64} %procedure(ptr %ctx, i64 %report)" & vbCrLf
    Text = Text & "  %success = extractvalue {i1,i64} %result, 0" & vbCrLf
    Text = Text & "  %still.owner = load atomic ptr, ptr %owner.ptr acquire, align 8" & vbCrLf
    Text = Text & "  %unfinished = icmp eq ptr %still.owner, %ctx" & vbCrLf
    Text = Text & "  br i1 %unfinished, label %abort, label %restore" & vbCrLf
    Text = Text & "abort:" & vbCrLf
    Text = Text & "  %failure = load atomic i64, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  %finished = call i1 @ube.managed.end(ptr %ctx, i64 0, i64 %failure)" & vbCrLf
    Text = Text & "  br label %restore" & vbCrLf
    Text = Text & "restore:" & vbCrLf
    Text = Text & "  store atomic i64 %incoming.depth, ptr %depth.ptr monotonic, align 8" & vbCrLf
    Text = Text & "  %reporting = icmp ne i64 %report, 0" & vbCrLf
    Text = Text & "  br i1 %reporting, label %done, label %preserve" & vbCrLf
    Text = Text & "preserve:" & vbCrLf
    Text = Text & "  store atomic i64 %incoming.error, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %done" & vbCrLf
    Text = Text & "done:" & vbCrLf
    Text = Text & "  ret {i1,i64} %result" & vbCrLf
    Text = Text & "suppressed:" & vbCrLf
    Text = Text & "  ret {i1,i64} {i1 true,i64 0}" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedCallbackIR = Text
End Function

Private Function ManagedWorkspaceIR() As String
    Dim Text As String
    Text = Text & "; The bounded heap's numeric traversal queue is reserved within the same program quota." & vbCrLf
    Text = Text & "define i1 @ube.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %state = call ptr @ube.managed.owned(ptr %ctx)" & vbCrLf
    Text = Text & "  %ready = icmp ne ptr %state, null" & vbCrLf
    Text = Text & "  br i1 %ready, label %validate, label %failed" & vbCrLf
    Text = Text & "validate:" & vbCrLf
    Text = Text & "  %not.preserve = icmp eq i64 %preserve, 0" & vbCrLf
    Text = Text & "  %nonnegative = icmp sge i64 %count, 0" & vbCrLf
    Text = Text & "  %arguments = and i1 %not.preserve, %nonnegative" & vbCrLf
    Text = Text & "  br i1 %arguments, label %capacity, label %bad" & vbCrLf
    Text = Text & "capacity:" & vbCrLf
    Text = Text & "  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16" & vbCrLf
    Text = Text & "  %capacity.value = load i64, ptr %capacity.ptr, align 8" & vbCrLf
    Text = Text & "  %fits = icmp ule i64 %count, %capacity.value" & vbCrLf
    Text = Text & "  br i1 %fits, label %descriptor, label %memory" & vbCrLf
    Text = Text & "descriptor:" & vbCrLf
    Text = Text & "  %upper.ptr = getelementptr i64, ptr %array, i64 1" & vbCrLf
    Text = Text & "  %data.ptr = getelementptr i64, ptr %array, i64 2" & vbCrLf
    Text = Text & "  %block.ptr = getelementptr i64, ptr %array, i64 3" & vbCrLf
    Text = Text & "  %lower = load i64, ptr %array, align 8" & vbCrLf
    Text = Text & "  %upper = load i64, ptr %upper.ptr, align 8" & vbCrLf
    Text = Text & "  %data = load ptr, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  %block = load ptr, ptr %block.ptr, align 8" & vbCrLf
    Text = Text & "  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14" & vbCrLf
    Text = Text & "  %lease = load ptr, ptr %lease.ptr, align 8" & vbCrLf
    Text = Text & "  %unowned = icmp eq ptr %block, null" & vbCrLf
    Text = Text & "  %empty = icmp slt i64 %upper, %lower" & vbCrLf
    Text = Text & "  %unleased = icmp eq ptr %lease, null" & vbCrLf
    Text = Text & "  %mine = icmp eq ptr %lease, %array" & vbCrLf
    Text = Text & "  %zero = icmp eq i64 %count, 0" & vbCrLf
    Text = Text & "  br i1 %zero, label %release.check, label %acquire.check" & vbCrLf
    Text = Text & "release.check:" & vbCrLf
    Text = Text & "  %empty.unleased = and i1 %empty, %unleased" & vbCrLf
    Text = Text & "  %releasable = or i1 %mine, %empty.unleased" & vbCrLf
    Text = Text & "  %release.valid = and i1 %releasable, %unowned" & vbCrLf
    Text = Text & "  br i1 %release.valid, label %release, label %bad" & vbCrLf
    Text = Text & "release:" & vbCrLf
    Text = Text & "  store i64 0, ptr %array, align 8" & vbCrLf
    Text = Text & "  store i64 -1, ptr %upper.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr null, ptr %lease.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "acquire.check:" & vbCrLf
    Text = Text & "  %empty.unowned = and i1 %empty, %unowned" & vbCrLf
    Text = Text & "  %available = and i1 %empty.unowned, %unleased" & vbCrLf
    Text = Text & "  br i1 %available, label %acquire, label %bad" & vbCrLf
    Text = Text & "acquire:" & vbCrLf
    Text = Text & "  %workspace.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 13" & vbCrLf
    Text = Text & "  %workspace = load ptr, ptr %workspace.ptr, align 8" & vbCrLf
    Text = Text & "  br label %clear" & vbCrLf
    Text = Text & "clear:" & vbCrLf
    Text = Text & "  %index = phi i64 [ 0, %acquire ], [ %next, %clear ]" & vbCrLf
    Text = Text & "  %cell = getelementptr i64, ptr %workspace, i64 %index" & vbCrLf
    Text = Text & "  store volatile i64 0, ptr %cell, align 8" & vbCrLf
    Text = Text & "  %next = add i64 %index, 1" & vbCrLf
    Text = Text & "  %more = icmp ult i64 %next, %count" & vbCrLf
    Text = Text & "  br i1 %more, label %clear, label %publish" & vbCrLf
    Text = Text & "publish:" & vbCrLf
    Text = Text & "  %last = sub i64 %count, 1" & vbCrLf
    Text = Text & "  store i64 0, ptr %array, align 8" & vbCrLf
    Text = Text & "  store i64 %last, ptr %upper.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %workspace, ptr %data.ptr, align 8" & vbCrLf
    Text = Text & "  store ptr %array, ptr %lease.ptr, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "bad:" & vbCrLf
    Text = Text & "  store atomic i64 5, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "memory:" & vbCrLf
    Text = Text & "  store atomic i64 7, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    ManagedWorkspaceIR = Text
End Function

Private Function CandidateAccessIR() As String
    Dim Text As String
    Text = Text & "define i1 @ube.text.candidate.info(ptr %ctx, i64 %identity, ptr %bytes.out, ptr %scalars.out) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %empty = icmp eq i64 %identity, 0" & vbCrLf
    Text = Text & "  br i1 %empty, label %zero, label %find" & vbCrLf
    Text = Text & "find:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %read, label %failed" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %scalars.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 6" & vbCrLf
    Text = Text & "  %bytes = load i64, ptr %bytes.ptr, align 8" & vbCrLf
    Text = Text & "  %scalars = load i64, ptr %scalars.ptr, align 8" & vbCrLf
    Text = Text & "  store i64 %bytes, ptr %bytes.out, align 8" & vbCrLf
    Text = Text & "  store i64 %scalars, ptr %scalars.out, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "zero:" & vbCrLf
    Text = Text & "  store i64 0, ptr %bytes.out, align 8" & vbCrLf
    Text = Text & "  store i64 0, ptr %scalars.out, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    Text = Text & "define i1 @ube.text.candidate.read(ptr %ctx, i64 %identity, i64 %index, ptr %output) {" & vbCrLf
    Text = Text & "entry:" & vbCrLf
    Text = Text & "  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)" & vbCrLf
    Text = Text & "  %exists = icmp ne ptr %record, null" & vbCrLf
    Text = Text & "  br i1 %exists, label %bounds, label %failed" & vbCrLf
    Text = Text & "bounds:" & vbCrLf
    Text = Text & "  %length.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5" & vbCrLf
    Text = Text & "  %length = load i64, ptr %length.ptr, align 8" & vbCrLf
    Text = Text & "  %valid = icmp ult i64 %index, %length" & vbCrLf
    Text = Text & "  br i1 %valid, label %read, label %range" & vbCrLf
    Text = Text & "read:" & vbCrLf
    Text = Text & "  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9" & vbCrLf
    Text = Text & "  %payload = load ptr, ptr %payload.ptr, align 8" & vbCrLf
    Text = Text & "  %address = getelementptr i8, ptr %payload, i64 %index" & vbCrLf
    Text = Text & "  %byte = load i8, ptr %address, align 1" & vbCrLf
    Text = Text & "  %wide = zext i8 %byte to i64" & vbCrLf
    Text = Text & "  store i64 %wide, ptr %output, align 8" & vbCrLf
    Text = Text & "  ret i1 true" & vbCrLf
    Text = Text & "range:" & vbCrLf
    Text = Text & "  store atomic i64 9, ptr %ctx monotonic, align 8" & vbCrLf
    Text = Text & "  br label %failed" & vbCrLf
    Text = Text & "failed:" & vbCrLf
    Text = Text & "  ret i1 false" & vbCrLf
    Text = Text & "}" & vbCrLf
    CandidateAccessIR = Text
End Function
