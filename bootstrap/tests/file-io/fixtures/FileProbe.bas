UBE SOURCE 1 MODULE
Attribute UBE_Name = "FileProbe"
' Exercises portable counted file APIs using paths supplied by the independent harness.
Private InputPath() As Byte
Private OutputPath() As Byte
Private Owner As Long

' An arbitrary declaration spelling acquires meaning only from its explicit role attribute.
Public Intrinsic Function ReadChunk(ByVal Token As Long, ByRef Destination() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef ReadCount As Long, ByRef Failure As Long) As Boolean
Attribute ReadChunk.UBE_Primitive = "fIlE.tRyReAd"
End Function

' Primary allocation error survives a different cleanup-close error and retained ownership.
Public Function CheckPrimaryAllocationError(ByVal Seed As Long) As Long
    Dim Result(0 To 0) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Dim Value As Long
    Result(0) = 77
    Status = FileBytes.TryReadAllBytes(InputPath, 4096, Result, Token, Failure)
    If Status <> False Then CheckPrimaryAllocationError = 1: GoTo ReleaseOwner
    If Failure <> 8 Then CheckPrimaryAllocationError = 2: GoTo ReleaseOwner
    If Err.Number <> 7 Then CheckPrimaryAllocationError = 3: GoTo ReleaseOwner
    If Token <= 0 Then CheckPrimaryAllocationError = 4: Exit Function
    Value = Result(0)
    If Value <> 77 Then CheckPrimaryAllocationError = 5: GoTo ReleaseOwner
    CheckPrimaryAllocationError = 0
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckPrimaryAllocationError = 6
End Function

' Exhausts the bounded registry, releases every owner, and proves slot reuse keeps fresh identities.
Public Function CheckRegistryCapacity(ByVal Seed As Long) As Long
    Dim Tokens(0 To 63) As Long
    Dim Data(0 To 0) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Dim Length As Long
    Dim Progress As Long
    Dim Index As Long
    Dim Previous As Long
    Dim Outcome As Long
OpenNext:
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then Outcome = 1: GoTo Cleanup
    Tokens(Index) = Token
    Previous = Token
    Token = 0
    Index = Index + 1
    If Index < 64 Then GoTo OpenNext
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status <> False Then Outcome = 2: GoTo Cleanup
    If Failure <> 8 Then Outcome = 3: GoTo Cleanup
    If Err.Number <> 7 Then Outcome = 4: GoTo Cleanup
Cleanup:
    Status = FilePrimitives.TryClose(Token, Failure)
    Index = 0
CloseNext:
    Status = FilePrimitives.TryClose(Tokens(Index), Failure)
    If Status = False Then Outcome = 5
    Index = Index + 1
    If Index < 64 Then GoTo CloseNext
    If Outcome <> 0 Then CheckRegistryCapacity = Outcome: Exit Function
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then CheckRegistryCapacity = 6: Exit Function
    If Token <= Previous Then CheckRegistryCapacity = 7
    Status = FilePrimitives.TryRead(Previous, Data, 0, 1, Progress, Failure)
    If Status <> False Then CheckRegistryCapacity = 8
    If Failure <> 9 Then CheckRegistryCapacity = 9
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckRegistryCapacity = 10
End Function

' Covers empty and full-capacity file payloads with ordinary source progress loops.
Public Function CheckSizes(ByVal Count As Long) As Long
    Dim Source() As Byte
    Dim Result() As Byte
    Dim Status As Boolean
    Dim Failure As Long
    Dim Token As Long
    Dim Index As Long
    Dim Value As Long
    Status = BufferPrimitives.TryResizeBytes(Source, Count, False)
    If Status = False Then CheckSizes = 1: Exit Function
    If Count = 0 Then GoTo CreateOutput
FillSized:
    Source(Index) = 7
    Index = Index + 1
    If Index < Count Then GoTo FillSized
CreateOutput:
    Status = FilePrimitives.TryCreateNew(OutputPath, Token, Failure)
    If Status = False Then CheckSizes = 2: Exit Function
    Status = FileBytes.TryWriteAllBytes(Token, Source, Failure)
    If Status = False Then CheckSizes = 3: GoTo ReleaseOwner
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckSizes = 4: Exit Function
    Status = FileBytes.TryReadAllBytes(OutputPath, 4096, Result, Token, Failure)
    If Status = False Then CheckSizes = 5: GoTo ReleaseOwner
    Value = BufferPrimitives.ByteStorageLength(Result)
    If Value <> Count Then CheckSizes = 6: Exit Function
    If Count = 0 Then CheckSizes = 0: Exit Function
    Index = 0
CompareSized:
    Value = Result(Index)
    If Value <> 7 Then CheckSizes = 7: Exit Function
    Index = Index + 1
    If Index < Count Then GoTo CompareSized
    CheckSizes = 0
    Exit Function
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Rejected size admission still publishes explicit ownership when native close fails.
Public Function CheckOpenCloseFailure(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Token As Long
    Dim Length As Long
    Dim Failure As Long
    Status = FilePrimitives.TryOpen(InputPath, 3, Token, Length, Failure)
    If Status <> False Then CheckOpenCloseFailure = 1: GoTo ReleaseOwner
    If Failure <> 7 Then CheckOpenCloseFailure = 2: GoTo ReleaseOwner
    If Token <= 0 Then CheckOpenCloseFailure = 3: Exit Function
    If Length <> 0 Then CheckOpenCloseFailure = 4: GoTo ReleaseOwner
    CheckOpenCloseFailure = 0
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckOpenCloseFailure = 5
End Function

' Exposes only the opaque source token, never its native handle.
Public Function CurrentOwner() As Long
    CurrentOwner = Owner
End Function

' A token from a different execution context cannot name this context's live file.
Public Function CheckForeignOwner(ByVal ForeignToken As Long) As Long
    Dim Destination(0 To 0) As Byte
    Dim Status As Boolean
    Dim Progress As Long
    Dim Failure As Long
    Status = FilePrimitives.TryRead(ForeignToken, Destination, 0, 1, Progress, Failure)
    If Status <> False Then CheckForeignOwner = 1: Exit Function
    If Failure <> 9 Then CheckForeignOwner = 2: Exit Function
    Status = FilePrimitives.TryRead(Owner, Destination, 0, 1, Progress, Failure)
    If Status = False Then CheckForeignOwner = 3: Exit Function
    If Progress <> 1 Then CheckForeignOwner = 4: Exit Function
    CheckForeignOwner = 0
End Function

' A failed native read cannot publish even bytes already written to its private scratch.
Public Function CheckReadAtomicity(ByVal Seed As Long) As Long
    Dim Destination(0 To 3) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Index As Long
    Dim Value As Long
FillAtomic:
    Destination(Index) = 55
    Index = Index + 1
    If Index < 4 Then GoTo FillAtomic
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then CheckReadAtomicity = 1: Exit Function
    Progress = 99
    Status = FilePrimitives.TryRead(Token, Destination, 0, 4, Progress, Failure)
    If Status <> False Then CheckReadAtomicity = 2: GoTo ReleaseOwner
    If Progress <> 0 Then CheckReadAtomicity = 3: GoTo ReleaseOwner
    If Failure <> 5 Then CheckReadAtomicity = 4: GoTo ReleaseOwner
    Index = 0
CompareAtomic:
    Value = Destination(Index)
    If Value <> 55 Then CheckReadAtomicity = 5: GoTo ReleaseOwner
    Index = Index + 1
    If Index < 4 Then GoTo CompareAtomic
    CheckReadAtomicity = 0
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Rejects malformed counted paths, size limits, wrong modes and stale identities safely.
Public Function CheckInvalidRequests(ByVal Seed As Long) As Long
    Dim EmptyPath() As Byte
    Dim BadPath(0 To 1) As Byte
    Dim Data(0 To 0) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Progress As Long
    Status = FilePrimitives.TryOpen(EmptyPath, 4096, Token, Length, Failure)
    If Status <> False Then CheckInvalidRequests = 1: GoTo ReleaseOwner
    If Failure <> 2 Then CheckInvalidRequests = 2: Exit Function
    BadPath(0) = 97
    BadPath(1) = 0
    Status = FilePrimitives.TryOpen(BadPath, 4096, Token, Length, Failure)
    If Status <> False Then CheckInvalidRequests = 3: GoTo ReleaseOwner
    If Failure <> 2 Then CheckInvalidRequests = 4: Exit Function
    BadPath(0) = 192
    BadPath(1) = 175
    Status = FilePrimitives.TryOpen(BadPath, 4096, Token, Length, Failure)
    If Status <> False Then CheckInvalidRequests = 5: GoTo ReleaseOwner
    If Failure <> 2 Then CheckInvalidRequests = 6: Exit Function
    Status = FilePrimitives.TryOpen(InputPath, -Seed, Token, Length, Failure)
    If Status <> False Then CheckInvalidRequests = 7: GoTo ReleaseOwner
    If Failure <> 1 Then CheckInvalidRequests = 8: Exit Function
    Status = FilePrimitives.TryOpen(InputPath, 3, Token, Length, Failure)
    If Status <> False Then CheckInvalidRequests = 9: GoTo ReleaseOwner
    If Failure <> 4 Then CheckInvalidRequests = 10: Exit Function
    If Err.Number <> 6 Then CheckInvalidRequests = 11: Exit Function
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then CheckInvalidRequests = 12: Exit Function
    Status = FilePrimitives.TryWrite(Token, Data, 0, 1, Progress, Failure)
    If Status <> False Then CheckInvalidRequests = 13: GoTo ReleaseOwner
    If Failure <> 9 Then CheckInvalidRequests = 14: GoTo ReleaseOwner
    Status = FilePrimitives.TryFlush(Token, Failure)
    If Status <> False Then CheckInvalidRequests = 15: GoTo ReleaseOwner
    If Failure <> 9 Then CheckInvalidRequests = 16: GoTo ReleaseOwner
    Status = FilePrimitives.TryClose(Token, Failure)
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckInvalidRequests = 17: Exit Function
    If Failure <> 0 Then CheckInvalidRequests = 18: Exit Function
    If Err.Number <> 5 Then CheckInvalidRequests = 19: Exit Function
    CheckInvalidRequests = 0
    Exit Function
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Confirms partial failed writes report progress while leaving the source unchanged.
Public Function CheckPartialWrite(ByVal Seed As Long) As Long
    Dim Source(0 To 3) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Value As Long
    Source(0) = 1
    Source(1) = 2
    Source(2) = 3
    Source(3) = 4
    Status = FilePrimitives.TryCreateNew(OutputPath, Token, Failure)
    If Status = False Then CheckPartialWrite = 1: Exit Function
    Status = FilePrimitives.TryRead(Token, Source, 0, 1, Progress, Failure)
    If Status <> False Then CheckPartialWrite = 6: GoTo ReleaseOwner
    If Failure <> 9 Then CheckPartialWrite = 7: GoTo ReleaseOwner
    Status = FilePrimitives.TryWrite(Token, Source, 0, 4, Progress, Failure)
    If Status <> False Then CheckPartialWrite = 2: GoTo ReleaseOwner
    If Failure <> 15 Then CheckPartialWrite = 3: GoTo ReleaseOwner
    If Progress <> 2 Then CheckPartialWrite = 4: GoTo ReleaseOwner
    Value = Source(2)
    If Value <> 3 Then CheckPartialWrite = 5: GoTo ReleaseOwner
    CheckPartialWrite = 0
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Ordinary output policy rejects zero progress and preserves write or flush failure.
Public Function CheckWriteFailure(ByVal ExpectedFailure As Long) As Long
    Dim Source(0 To 3) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Source(0) = 1
    Source(1) = 2
    Source(2) = 3
    Source(3) = 4
    Status = FilePrimitives.TryCreateNew(OutputPath, Token, Failure)
    If Status = False Then CheckWriteFailure = 1: Exit Function
    Status = FileBytes.TryWriteAllBytes(Token, Source, Failure)
    If Status <> False Then CheckWriteFailure = 2: GoTo ReleaseOwner
    If Failure <> ExpectedFailure Then CheckWriteFailure = 3: GoTo ReleaseOwner
    If Err.Number <> 57 Then CheckWriteFailure = 4: GoTo ReleaseOwner
    CheckWriteFailure = 0
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' A caller explicitly closes retained ownership before raising its primary read error.
Public Function ReadThenRaise(ByVal Seed As Long) As Long
    Dim Result() As Byte
    Dim Status As Boolean
    Dim Failure As Long
    Dim PrimaryError As Long
    Status = FileBytes.TryReadAllBytes(InputPath, 4096, Result, Owner, Failure)
    If Status = True Then ReadThenRaise = 1: Exit Function
    PrimaryError = Err.Number
    Status = FilePrimitives.TryClose(Owner, Failure)
    If Status = False Then ReadThenRaise = 2: Exit Function
    Err.Raise PrimaryError
End Function

' Failed intake and close retry complete before Err.Raise skips caller assignment.
Public Function CheckCleanupBeforeRaise(ByVal Seed As Long) As Long
    Dim Result As Long = 77
    Result = ReadThenRaise(Seed)
    If Result <> 77 Then CheckCleanupBeforeRaise = 1: Exit Function
    If Owner <> 0 Then CheckCleanupBeforeRaise = 2: Exit Function
    If Err.Number <> 57 Then CheckCleanupBeforeRaise = 3: Exit Function
    CheckCleanupBeforeRaise = 0
End Function

' Opens a module-held owner for explicit lifetime and failed-close tests.
Public Function PrepareOpen(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Failure As Long
    Dim Length As Long
    Status = FilePrimitives.TryOpen(InputPath, 4096, Owner, Length, Failure)
    If Status = False Then PrepareOpen = 1 Else PrepareOpen = 0
End Function

' Releases the module-held owner after the harness has observed its live lifetime.
Public Function CloseOwner() As Long
    Dim Status As Boolean
    Dim Failure As Long
    Status = FilePrimitives.TryClose(Owner, Failure)
    If Status = False Then CloseOwner = 1 Else CloseOwner = 0
End Function

' Failed close retains ownership; a successful retry clears the same token.
Public Function CheckCloseRetry(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Failure As Long
    Dim Previous As Long
    Previous = Owner
    Status = FilePrimitives.TryClose(Owner, Failure)
    If Status <> False Then CheckCloseRetry = 1: Exit Function
    If Failure <> 7 Then CheckCloseRetry = 2: Exit Function
    If Owner <> Previous Then CheckCloseRetry = 3: Exit Function
    Status = FilePrimitives.TryClose(Owner, Failure)
    If Status = False Then CheckCloseRetry = 4: Exit Function
    If Owner <> 0 Then CheckCloseRetry = 5: Exit Function
    CheckCloseRetry = 0
End Function

' Failed ordinary intake closes before return and preserves the previous result value.
Public Function CheckReadFailure(ByVal ExpectedFailure As Long) As Long
    Dim Result(2 To 2) As Byte
    Dim Status As Boolean
    Dim Failure As Long
    Dim Token As Long
    Dim Value As Long
    Result(2) = 77
    Status = FileBytes.TryReadAllBytes(InputPath, 4096, Result, Token, Failure)
    If Status <> False Then CheckReadFailure = 1: GoTo ReleaseOwner
    If Failure <> ExpectedFailure Then CheckReadFailure = 2: GoTo ReleaseOwner
    If Token <> 0 Then CheckReadFailure = 3: GoTo ReleaseOwner
    Value = Result(2)
    If Value <> 77 Then CheckReadFailure = 4: Exit Function
    CheckReadFailure = 0
    Exit Function
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Validation failures return fresh usable status without jumping to a language handler.
Public Function CheckValidation(ByVal Seed As Long) As Long
    Dim Destination(0 To 3) As Byte
    Dim Result() As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Previous As Long
    On Error GoTo Unexpected
    Status = FilePrimitives.SetError(77)
    If Status <> False Then CheckValidation = 1: Exit Function
    If Err.Number <> 77 Then CheckValidation = 2: Exit Function
    Status = FilePrimitives.SetError(0)
    If Status <> False Then CheckValidation = 19: Exit Function
    If Err.Number <> 5 Then CheckValidation = 20: Exit Function
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then CheckValidation = 3: Exit Function
    Previous = Token
    Status = FileBytes.TryReadAllBytes(InputPath, 4096, Result, Token, Token)
    If Status <> False Then CheckValidation = 4: GoTo ReleaseOwner
    If Token <> Previous Then CheckValidation = 5: GoTo ReleaseOwner
    Progress = 88
    Status = FilePrimitives.TryRead(Token, Destination, 0, 1, Progress, Progress)
    If Status <> False Then CheckValidation = 6: GoTo ReleaseOwner
    If Progress <> 88 Then CheckValidation = 7: GoTo ReleaseOwner
    Status = FilePrimitives.TryRead(Token, Destination, 0, -Seed, Progress, Failure)
    If Status <> False Then CheckValidation = 8: GoTo ReleaseOwner
    If Failure <> 1 Then CheckValidation = 9: GoTo ReleaseOwner
    If Progress <> 0 Then CheckValidation = 10: GoTo ReleaseOwner
    If Err.Number <> 5 Then CheckValidation = 11: GoTo ReleaseOwner
    Status = FilePrimitives.TryRead(Token, Destination, 0, 65537, Progress, Failure)
    If Status <> False Then CheckValidation = 13: GoTo ReleaseOwner
    If Failure <> 1 Then CheckValidation = 14: GoTo ReleaseOwner
    Status = FilePrimitives.TryRead(Token, Destination, 2147483647, 1, Progress, Failure)
    If Status <> False Then CheckValidation = 15: GoTo ReleaseOwner
    If Failure <> 1 Then CheckValidation = 16: GoTo ReleaseOwner
    Status = FilePrimitives.TryRead(Token, Destination, 4, 0, Progress, Failure)
    If Status = False Then CheckValidation = 17: GoTo ReleaseOwner
    If Progress <> 0 Then CheckValidation = 18: GoTo ReleaseOwner
    Status = FilePrimitives.TryClose(Token, Failure)
    CheckValidation = 0
    Exit Function
Unexpected:
    CheckValidation = 12
ReleaseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Allocates exact counted path arrays before any file operation is attempted.
Public Function Configure(ByVal InputLength As Long, ByVal OutputLength As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, InputLength, False)
    If Status = False Then Configure = 1: Exit Function
    Status = BufferPrimitives.TryResizeBytes(OutputPath, OutputLength, False)
    If Status = False Then Configure = 2: Exit Function
    Configure = 0
End Function

' Installs one UTF-8 path byte through normal source-level array assignment.
Public Function SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Long) As Long
    If Kind = 0 Then InputPath(Index) = Value Else OutputPath(Index) = Value
    SetPathByte = 0
End Function

' Writes all byte values through progress policy, closes and independently reads them back.
Public Function CheckRoundTrip(ByVal Seed As Long) As Long
    Dim Source() As Byte
    Dim Result() As Byte
    Dim Status As Boolean
    Dim Failure As Long
    Dim Index As Long
    Dim Value As Long
    Dim Token As Long
    Status = BufferPrimitives.TryResizeBytes(Source, 256, False)
    If Status = False Then CheckRoundTrip = 11: Exit Function
Fill:
    Source(Index) = Index
    Index = Index + 1
    If Index < 256 Then GoTo Fill
    Status = FilePrimitives.SetError(77)
    Status = FilePrimitives.TryCreateNew(OutputPath, Token, Failure)
    If Status = False Then CheckRoundTrip = 1: Exit Function
    If Failure <> 0 Then CheckRoundTrip = 2: Exit Function
    If Err.Number <> 77 Then CheckRoundTrip = 3: Exit Function
    Status = FileBytes.TryWriteAllBytes(Token, Source, Failure)
    If Status = False Then CheckRoundTrip = 4: GoTo CloseOwner
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckRoundTrip = 5: Exit Function
    Status = FileBytes.TryReadAllBytes(OutputPath, 4096, Result, Token, Failure)
    If Status = False Then CheckRoundTrip = 6: GoTo CloseOwner
    If Err.Number <> 77 Then CheckRoundTrip = 13: Exit Function
    Value = BufferPrimitives.ByteStorageLength(Result)
    If Value <> 256 Then CheckRoundTrip = 7: Exit Function
    Index = 0
Compare:
    Value = Result(Index)
    If Value <> Index Then CheckRoundTrip = 8: Exit Function
    Value = Source(Index)
    If Value <> Index Then CheckRoundTrip = 12: Exit Function
    Index = Index + 1
    If Index < 256 Then GoTo Compare
    Status = FilePrimitives.TryCreateNew(OutputPath, Token, Failure)
    If Status <> False Then CheckRoundTrip = 9: GoTo CloseOwner
    If Failure <> 3 Then CheckRoundTrip = 10: Exit Function
    CheckRoundTrip = 0
    Exit Function
CloseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function

' Observes counted reads, short progress, EOF, nonzero bounds and explicit token lifetime.
Public Function CheckReads(ByVal Seed As Long) As Long
    Dim Destination(5 To 12) As Byte
    Dim Status As Boolean
    Dim Token As Long
    Dim Stale As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Value As Long
    Destination(9) = 99
    Status = FilePrimitives.TryOpen(InputPath, 4096, Token, Length, Failure)
    If Status = False Then CheckReads = 1: Exit Function
    If Length <> 4 Then CheckReads = 2: GoTo CloseOwner
    Stale = Token
    Status = ReadChunk(Token, Destination, Seed + -1, 8, Progress, Failure)
    If Status = False Then CheckReads = 3: GoTo CloseOwner
    If Progress <> 4 Then CheckReads = 4: GoTo CloseOwner
    Value = Destination(5)
    If Value <> 0 Then CheckReads = 5: GoTo CloseOwner
    Value = Destination(8)
    If Value <> 255 Then CheckReads = 6: GoTo CloseOwner
    Value = Destination(9)
    If Value <> 99 Then CheckReads = 7: GoTo CloseOwner
    Status = FilePrimitives.TryRead(Token, Destination, 0, 1, Progress, Failure)
    If Status = False Then CheckReads = 8: GoTo CloseOwner
    If Progress <> 0 Then CheckReads = 9: GoTo CloseOwner
    Status = FilePrimitives.TryClose(Token, Failure)
    If Status = False Then CheckReads = 10: Exit Function
    If Token <> 0 Then CheckReads = 11: Exit Function
    Status = FilePrimitives.TryRead(Stale, Destination, 0, 1, Progress, Failure)
    If Status <> False Then CheckReads = 12: Exit Function
    If Failure <> 9 Then CheckReads = 13: Exit Function
    CheckReads = 0
    Exit Function
CloseOwner:
    Status = FilePrimitives.TryClose(Token, Failure)
End Function
