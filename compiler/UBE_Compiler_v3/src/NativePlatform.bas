UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativePlatform"

' Windows x64 startup owns the native TLS floor. Immutable reserve metadata
' is supplied by the separately checked object/frame binding.
Function TryEmitNativePlatformSupport(ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativePlatformSupport = False
    Call ResetNativeFailure(Writer.Failure)
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 103, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "target triple = ""x86_64-w64-windows-gnu""") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.stack.floor = thread_local global i64 0, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.stack.reserve = external constant i64") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare dllimport i64 @VirtualQuery(ptr, ptr, i64)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare dllimport i32 @TerminateProcess(ptr, i32)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare dllimport void @ExitProcess(i32) noreturn") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare dllimport void @Sleep(i32)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define i1 @ube.stack.initialize(i64 %caller, i64 %first) {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %record = alloca [48 x i8], align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %allocationp = getelementptr i8, ptr %record, i64 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %sizep = getelementptr i8, ptr %record, i64 24") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %statep = getelementptr i8, ptr %record, i64 32") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %protectp = getelementptr i8, ptr %record, i64 36") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %typep = getelementptr i8, ptr %record, i64 40") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reserve = load i64, ptr @ube.stack.reserve, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %callerok = icmp ne i64 %caller, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %firstok = icmp ne i64 %first, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reserveok = icmp ne i64 %reserve, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %argsok = and i1 %callerok, %firstok") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %valid = and i1 %argsok, %reserveok") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %valid, label %initial, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "initial:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %below = sub i64 %caller, 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %address = inttoptr i64 %below to ptr") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %initialbytes = call i64 @VirtualQuery(ptr %address, ptr %record, i64 48)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %initialfull = icmp eq i64 %initialbytes, 48") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %initialfull, label %initialstate, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "initialstate:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %initialkind = load i32, ptr %statep, align 4") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %initialcommit = icmp eq i32 %initialkind, 4096") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %initialcommit, label %allocation, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "allocation:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %start = load i64, ptr %allocationp, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %startnonzero = icmp ne i64 %start, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %startbelow = icmp ult i64 %start, %caller") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %startok = and i1 %startnonzero, %startbelow") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %startok, label %query, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "query:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %cursor = phi i64 [ %start, %allocation ], [ %end, %advance ]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %run = phi i64 [ 0, %allocation ], [ %nextrun, %advance ]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %queryaddress = inttoptr i64 %cursor to ptr") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %bytes = call i64 @VirtualQuery(ptr %queryaddress, ptr %record, i64 48)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %full = icmp eq i64 %bytes, 48") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %full, label %region, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "region:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %base = load i64, ptr %record, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %size = load i64, ptr %sizep, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %end = add i64 %base, %size") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %positive = icmp ne i64 %size, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %nooverflow = icmp ugt i64 %end, %base") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %contains = icmp ule i64 %base, %cursor") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %progress = icmp ugt i64 %end, %cursor") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %ownedbase = icmp uge i64 %base, %start") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %sizeok = and i1 %positive, %nooverflow") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %rangeok = and i1 %contains, %progress") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %regionok = and i1 %sizeok, %rangeok") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %boundsok = and i1 %regionok, %ownedbase") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %boundsok, label %state, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "state:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %kind = load i32, ptr %statep, align 4") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %committed = icmp eq i32 %kind, 4096") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reserved = icmp eq i32 %kind, 8192") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %known = or i1 %committed, %reserved") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %known, label %owner, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "owner:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %allocationbase = load i64, ptr %allocationp, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %same = icmp eq i64 %allocationbase, %start") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %same, label %classify, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "classify:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %committed, label %protection, label %unusable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "protection:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %type = load i32, ptr %typep, align 4") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %private = icmp eq i32 %type, 131072") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %private, label %access, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "access:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %protect = load i32, ptr %protectp, align 4") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %baseprotect = and i32 %protect, 255") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %rw = icmp eq i32 %baseprotect, 4") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %xrw = icmp eq i32 %baseprotect, 64") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %writable = or i1 %rw, %xrw") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %guard = and i32 %protect, 256") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %unguarded = icmp eq i32 %guard, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %usable = and i1 %writable, %unguarded") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %usable, label %usablepage, label %unusable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "usablepage:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %emptyrun = icmp eq i64 %run, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %continued = select i1 %emptyrun, i64 %cursor, i64 %run") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %advance") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "unusable:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %advance") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "advance:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %nextrun = phi i64 [ %continued, %usablepage ], [ 0, %unusable ]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reached = icmp uge i64 %end, %caller") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %reached, label %finish, label %query") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "finish:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %hasrun = icmp ne i64 %nextrun, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %runbelow = icmp ult i64 %nextrun, %caller") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %suffixok = and i1 %hasrun, %runbelow") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %suffixok, label %capacity, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "capacity:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %available = sub i64 %caller, %nextrun") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reservedroom = icmp ule i64 %reserve, %available") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %reservedroom, label %footprint, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "footprint:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %remaining = sub i64 %available, %reserve") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %room = icmp ule i64 %first, %remaining") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %room, label %publish, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "publish:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  store i64 %nextrun, ptr @ube.stack.floor, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 true") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "failed:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 false") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define void @ube.stack.abort() noreturn {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %terminated = call i32 @TerminateProcess(ptr inttoptr (i64 -1 to ptr), i32 1)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %accepted = icmp ne i32 %terminated, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %accepted, label %done, label %fallback") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "fallback:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ExitProcess(i32 1)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  unreachable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "done:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  unreachable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define void @ube.module.wait() noreturn {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %waiting") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "waiting:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @Sleep(i32 -1)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %waiting") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    TryEmitNativePlatformSupport = True
End Function
