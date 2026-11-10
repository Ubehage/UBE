UBE SOURCE 1 MODULE
Attribute UBE_Name = "StorageProbe"
' Exercises larger byte buffers, counted file chunks, and per-block allocation admission.
Private InputPath() As Byte
Private OutputPath() As Byte
Private Bytes() As Byte
Private Backup() As Byte

Private Type WideRecord
    Cell0 As Long
    Cell1 As Long
    Cell2 As Long
    Cell3 As Long
    Cell4 As Long
    Cell5 As Long
    Cell6 As Long
    Cell7 As Long
    Cell8 As Long
    Cell9 As Long
    Cell10 As Long
    Cell11 As Long
    Cell12 As Long
    Cell13 As Long
    Cell14 As Long
    Cell15 As Long
    Cell16 As Long
    Cell17 As Long
    Cell18 As Long
    Cell19 As Long
    Cell20 As Long
    Cell21 As Long
    Cell22 As Long
    Cell23 As Long
    Cell24 As Long
    Cell25 As Long
    Cell26 As Long
    Cell27 As Long
    Cell28 As Long
    Cell29 As Long
    Cell30 As Long
    Cell31 As Long
    Cell32 As Long
    Cell33 As Long
    Cell34 As Long
    Cell35 As Long
    Cell36 As Long
    Cell37 As Long
    Cell38 As Long
    Cell39 As Long
    Cell40 As Long
    Cell41 As Long
    Cell42 As Long
    Cell43 As Long
    Cell44 As Long
    Cell45 As Long
    Cell46 As Long
    Cell47 As Long
    Cell48 As Long
    Cell49 As Long
    Cell50 As Long
    Cell51 As Long
    Cell52 As Long
    Cell53 As Long
    Cell54 As Long
    Cell55 As Long
    Cell56 As Long
    Cell57 As Long
    Cell58 As Long
    Cell59 As Long
    Cell60 As Long
    Cell61 As Long
    Cell62 As Long
    Cell63 As Long
    Cell64 As Long
    Cell65 As Long
    Cell66 As Long
    Cell67 As Long
    Cell68 As Long
    Cell69 As Long
    Cell70 As Long
    Cell71 As Long
    Cell72 As Long
    Cell73 As Long
    Cell74 As Long
    Cell75 As Long
    Cell76 As Long
    Cell77 As Long
    Cell78 As Long
    Cell79 As Long
    Cell80 As Long
    Cell81 As Long
    Cell82 As Long
    Cell83 As Long
    Cell84 As Long
    Cell85 As Long
    Cell86 As Long
    Cell87 As Long
    Cell88 As Long
    Cell89 As Long
    Cell90 As Long
    Cell91 As Long
    Cell92 As Long
    Cell93 As Long
    Cell94 As Long
    Cell95 As Long
    Cell96 As Long
    Cell97 As Long
    Cell98 As Long
    Cell99 As Long
    Cell100 As Long
    Cell101 As Long
    Cell102 As Long
    Cell103 As Long
    Cell104 As Long
    Cell105 As Long
    Cell106 As Long
    Cell107 As Long
    Cell108 As Long
    Cell109 As Long
    Cell110 As Long
    Cell111 As Long
    Cell112 As Long
    Cell113 As Long
    Cell114 As Long
    Cell115 As Long
    Cell116 As Long
    Cell117 As Long
    Cell118 As Long
    Cell119 As Long
    Cell120 As Long
    Cell121 As Long
    Cell122 As Long
    Cell123 As Long
    Cell124 As Long
    Cell125 As Long
    Cell126 As Long
    Cell127 As Long
End Type
Private Wide() As WideRecord

' Resizes a finite scalar record array through normal primitive binding.
Private Intrinsic Function ResizeWide(ByRef Values() As WideRecord, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeWide.UBE_Primitive = "Array.TryResize"
End Function

' Measures actual retained records after rejected replacement.
Private Intrinsic Function WideLength(ByRef Values() As WideRecord) As Long
Attribute WideLength.UBE_Primitive = "Array.Length"
End Function

' Allocates path buffers before native file observations begin.
Public Function Configure(ByVal InputLength As Long, ByVal OutputLength As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, InputLength, False)
    If Status = False Then Configure = 1: Exit Function
    Status = BufferPrimitives.TryResizeBytes(OutputPath, OutputLength, False)
    If Status = False Then Configure = 2: Exit Function
    Configure = 0
End Function

' Supplies one counted input path byte from the independent harness.
Public Function SetInput(ByVal Index As Long, ByVal Value As Byte) As Long
    InputPath(Index) = Value
    SetInput = 0
End Function

' Supplies one counted output path byte from the independent harness.
Public Function SetOutput(ByVal Index As Long, ByVal Value As Byte) As Long
    OutputPath(Index) = Value
    SetOutput = 0
End Function

' Checks every input byte, then writes the independently verified whole buffer through chunked policy.
Public Function RoundTrip(ByVal ExpectedLength As Long) As Long
    Dim Status As Boolean
    Dim Owner As Long
    Dim Failure As Long
    Dim Index As Long
    Dim Expected As Long
    Dim Result As Long
    On Error GoTo Unexpected
    Status = FileBytes.TryReadAllBytes(InputPath, 1048576, Bytes, Owner, Failure)
    If Status = False Then Result = 1: GoTo Cleanup
    If BufferPrimitives.ByteStorageLength(Bytes) <> ExpectedLength Then Result = 2: GoTo Cleanup
    Do While Index < ExpectedLength
        If Bytes(Index) <> Expected Then Result = 3: GoTo Cleanup
        Index = Index + 1
        Expected = Expected + 1
        If Expected = 256 Then Expected = 0
    Loop
    Status = FilePrimitives.TryCreateNew(OutputPath, Owner, Failure)
    If Status = False Then Result = 4: GoTo Cleanup
    Status = FileBytes.TryWriteAllBytes(Owner, Bytes, Failure)
    If Status = False Then Result = 5
Cleanup:
    If Owner <> 0 Then
        Status = FilePrimitives.TryClose(Owner, Failure)
        If Status = False Then Result = 6
    End If
    RoundTrip = Result
    Exit Function
Unexpected:
    Result = 99
    GoTo Cleanup
End Function

' Proves the exact native transfer ceiling and preserves a destination cell after it.
Public Function TransferBoundary() As Long
    Dim Status As Boolean
    Dim Owner As Long
    Dim Failure As Long
    Dim Length As Long
    Dim Progress As Long
    Dim Result As Long
    Dim Index As Long
    Dim Expected As Long
    On Error GoTo Unexpected
    Status = BufferPrimitives.TryResizeBytes(Bytes, 65537, False)
    If Status = False Then TransferBoundary = 1: Exit Function
    Bytes(65536) = 199
    Status = FilePrimitives.TryOpen(InputPath, 1048576, Owner, Length, Failure)
    If Status = False Then Result = 2: GoTo Cleanup
    Status = FilePrimitives.TryRead(Owner, Bytes, 0, 65537, Progress, Failure)
    If Status Or Progress <> 0 Or Failure <> 1 Then Result = 3: GoTo Cleanup
    Status = FilePrimitives.TryRead(Owner, Bytes, 0, 65536, Progress, Failure)
    If Status = False Or Progress <> 65536 Then Result = 4: GoTo Cleanup
    If Bytes(65536) <> 199 Then Result = 5: GoTo Cleanup
    Do While Index < 65536
        If Bytes(Index) <> Expected Then Result = 6: GoTo Cleanup
        Index = Index + 1
        Expected = Expected + 1
        If Expected = 256 Then Expected = 0
    Loop
    Status = FilePrimitives.TryClose(Owner, Failure)
    If Status = False Then Result = 7: GoTo Cleanup
    Status = BufferPrimitives.TryCopyBytes(Backup, Bytes)
    If Status = False Then Result = 8: GoTo Cleanup
    Backup(0) = 77
    If Bytes(0) <> 0 Then Result = 9: GoTo Cleanup
    Status = FilePrimitives.TryCreateNew(OutputPath, Owner, Failure)
    If Status = False Then Result = 10: GoTo Cleanup
    Status = FilePrimitives.TryWrite(Owner, Bytes, 0, 65537, Progress, Failure)
    If Status Or Progress <> 0 Or Failure <> 1 Then Result = 11: GoTo Cleanup
    Status = FilePrimitives.TryWrite(Owner, Bytes, 0, 65536, Progress, Failure)
    If Status = False Or Progress <> 65536 Then Result = 12: GoTo Cleanup
    Status = FilePrimitives.TryFlush(Owner, Failure)
    If Status = False Then Result = 13
Cleanup:
    If Owner <> 0 Then
        Status = FilePrimitives.TryClose(Owner, Failure)
        If Status = False Then Result = 14
    End If
    TransferBoundary = Result
    Exit Function
Unexpected:
    Result = 99
    GoTo Cleanup
End Function

' Rejects a file above the whole-source limit before reading payload or replacing prior bytes.
Public Function RejectFileLimit() As Long
    Dim Status As Boolean
    Dim Owner As Long
    Dim Failure As Long
    On Error GoTo Failed
    Status = BufferPrimitives.TryResizeBytes(Bytes, 1, False)
    If Status = False Then RejectFileLimit = 1: Exit Function
    Bytes(0) = 77
    Status = FileBytes.TryReadAllBytes(InputPath, 2147483647, Bytes, Owner, Failure)
    If Status Or Failure <> 4 Or Owner <> 0 Or Err.Number <> 6 Then RejectFileLimit = 2: Exit Function
    If BufferPrimitives.ByteStorageLength(Bytes) <> 1 Then RejectFileLimit = 3: Exit Function
    If Bytes(0) <> 77 Then RejectFileLimit = 4: Exit Function
    RejectFileLimit = 0
    Exit Function
Failed:
    RejectFileLimit = 99
End Function

' Holds small prior values before the native observer starts counting rejected requests.
Public Function PrepareQuota() As Long
    Dim Status As Boolean
    Status = ResizeWide(Wide, 1, False)
    If Status = False Then PrepareQuota = 1: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Bytes, 1, False)
    If Status = False Then PrepareQuota = 2: Exit Function
    Wide(0).Cell127 = 123
    Bytes(0) = 77
    PrepareQuota = 0
End Function

' Rejects both an over-quota payload and an excessive element count before any target allocation.
Public Function RejectQuota() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = ResizeWide(Wide, 65536, True)
    If Status Then RejectQuota = 1: Exit Function
    If Err.Number <> 7 Or WideLength(Wide) <> 1 Then RejectQuota = 2: Exit Function
    If Wide(0).Cell127 <> 123 Then RejectQuota = 3: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Bytes, 1048577, True)
    If Status Then RejectQuota = 4: Exit Function
    If Err.Number <> 7 Or BufferPrimitives.ByteStorageLength(Bytes) <> 1 Then RejectQuota = 5: Exit Function
    If Bytes(0) <> 77 Then RejectQuota = 6: Exit Function
    RejectQuota = 0
    Exit Function
Failed:
    RejectQuota = 99
End Function

' Confirms an admitted replacement still works after both rejected attempts.
Public Function RetryQuota() As Long
    Dim Status As Boolean
    Status = ResizeWide(Wide, 2, True)
    If Status = False Then RetryQuota = 1: Exit Function
    If Wide(0).Cell127 <> 123 Or Wide(1).Cell127 <> 0 Then RetryQuota = 2: Exit Function
    If Err.Number <> 7 Then RetryQuota = 3: Exit Function
    RetryQuota = 0
End Function
