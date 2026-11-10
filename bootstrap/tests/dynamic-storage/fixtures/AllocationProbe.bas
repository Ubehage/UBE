UBE SOURCE 1 MODULE
Attribute UBE_Name = "AllocationProbe"
' Retains module owners while the native harness injects target allocator failures.
Private Destination() As Byte
Private Source() As Byte

' Establishes distinguishable live owners before enabling allocator faults.
Public Function Prepare(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Destination, Seed + 1, False)
    If Status = False Then Prepare = 1: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Source, Seed + 1, False)
    If Status = False Then Prepare = 2: Exit Function
    Destination(0) = 7
    Destination(1) = 8
    Source(0) = 17
    Source(1) = 18
    Prepare = 0
End Function

' A failed allocation is a usable False without transferring to the enabled handler.
Public Function CheckRejectedResize(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Value As Long
    On Error GoTo Unexpected
    Status = True
    Status = BufferPrimitives.TryResizeBytes(Destination, Seed + 2, True)
    If Status <> False Then CheckRejectedResize = 1: Exit Function
    If Err.Number <> 7 Then CheckRejectedResize = 2: Exit Function
    Value = BufferPrimitives.ByteStorageLength(Destination)
    If Value <> 2 Then CheckRejectedResize = 3: Exit Function
    Value = Destination(0)
    If Value <> 7 Then CheckRejectedResize = 4: Exit Function
    Value = Destination(1)
    If Value <> 8 Then CheckRejectedResize = 5: Exit Function
    CheckRejectedResize = 0
    Exit Function
Unexpected:
    CheckRejectedResize = 6
End Function

' A successful retry preserves both the old payload and a sticky error number.
Public Function CheckRetry(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Value As Long
    DynamicProbe.RaiseFive
    Status = BufferPrimitives.TryResizeBytes(Destination, Seed + 2, True)
    If Status = False Then CheckRetry = 1: Exit Function
    If Err.Number <> 5 Then CheckRetry = 2: Exit Function
    Value = Destination(0)
    If Value <> 7 Then CheckRetry = 3: Exit Function
    Value = Destination(2)
    If Value <> 0 Then CheckRetry = 4: Exit Function
    CheckRetry = 0
End Function

' Copy preparation failure leaves the destination owner and payload intact.
Public Function CheckRejectedCopy(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Value As Long
    Status = BufferPrimitives.TryCopyBytes(Destination, Source)
    If Status <> False Then CheckRejectedCopy = 1: Exit Function
    If Err.Number <> 7 Then CheckRejectedCopy = 2: Exit Function
    Value = Destination(0)
    If Value <> 7 Then CheckRejectedCopy = 3: Exit Function
    Value = Source(0)
    If Value <> 17 Then CheckRejectedCopy = 4: Exit Function
    CheckRejectedCopy = 0
End Function

' Ordinary copy raises a language failure and enters the caller's selected handler.
Public Function CheckAssignmentFailure(ByVal Seed As Long) As Long
    Dim Value As Long
    On Error GoTo Failed
    Destination = Source
    CheckAssignmentFailure = 1
    Exit Function
Failed:
    If Err.Number <> 7 Then CheckAssignmentFailure = 2: Exit Function
    Value = Destination(0)
    If Value <> 7 Then CheckAssignmentFailure = 3: Exit Function
    CheckAssignmentFailure = 0
End Function

' Invalid counts return record-only status before touching existing storage.
Public Function CheckCounts(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Value As Long
    Status = BufferPrimitives.TryResizeBytes(Destination, -Seed, True)
    If Status <> False Then CheckCounts = 1: Exit Function
    If Err.Number <> 5 Then CheckCounts = 2: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Destination, 4096 + Seed, True)
    If Status <> False Then CheckCounts = 3: Exit Function
    If Err.Number <> 7 Then CheckCounts = 4: Exit Function
    Value = Destination(0)
    If Value <> 7 Then CheckCounts = 5: Exit Function
    CheckCounts = 0
End Function
