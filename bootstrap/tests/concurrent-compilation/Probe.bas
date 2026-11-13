UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
' Drives independent compiler requests in one process with retained structured outcomes.
Private ManifestA() As Byte
Private ManifestB() As Byte
Private OutputA() As Byte
Private OutputB() As Byte
Private ClangA() As Byte
Private ClangB() As Byte
Private RequestModeA As Long
Private RequestModeB As Long
Private DiagnosticA() As Byte
Private DiagnosticB() As Byte
Public Type Observation
    Completed As Boolean
    Cleaned As Boolean
    Diagnostic As CompilationRequest.RequestDiagnostic
    PathLength As Long
    ErrorNumber As Long
    FirstWork As Long
    SecondWork As Long
    FirstBytes As Long
    SecondBytes As Long
    FirstLines As Long
    SecondLines As Long
    NodeCount As Long
End Type
Private Results() As Observation

' Allocates disjoint result slots before any test worker is published.
Private Intrinsic Function ResizeResults(ByRef Values() As Observation, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeResults.UBE_Primitive = "Array.TryResize"
End Function

' Reads retained range results without indexing unprepared requests.
Private Intrinsic Function RangeCount(ByRef Ranges() As NativeCompilation.RangeResult) As Long
Attribute RangeCount.UBE_Primitive = "Array.Length"
End Function

' Creates retained cleanup records independently from the compiler request path.
Private Intrinsic Function ResizeCleanupRanges(ByRef Ranges() As NativeCompilation.RangeResult, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeCleanupRanges.UBE_Primitive = "Array.TryResize"
End Function

' Leaves its file owned by the request so the cleanup test can inject a close failure after completion.
Private Sub HoldCleanupFile(ByRef Result As NativeCompilation.RangeResult, ByRef Path() As Byte)
    If FilePrimitives.TryCreateNew(Path, Result.FileToken, Result.Failure) Then Result.Completed = True
End Sub

' Requires all source workers to be observed despite an earlier retained close failure, then retries cleanup.
Public Function CheckCleanup() As Long
    Dim Ranges() As NativeCompilation.RangeResult
    Dim Failure As Long
    Dim Status As Boolean
    Dim Code As Long
    On Error GoTo Failed
    If Not ResizeCleanupRanges(Ranges, 2, False) Then CheckCleanup = 1: Exit Function
    Ranges(0).FirstSymbol = 1
    Ranges(1).FirstSymbol = 2
    Ranges(0).ThreadId = CallNew HoldCleanupFile(Ranges(0), OutputA)
    Ranges(1).ThreadId = CallNew HoldCleanupFile(Ranges(1), OutputB)
    Status = NativeCompilation.TryCleanup(Ranges, Failure)
    If Status Then Code = 2
    If Not Ranges(0).SourceFinished Or Not Ranges(1).SourceFinished Then Code = 3
    If Ranges(0).FileToken = 0 Or Ranges(1).FileToken <> 0 Then Code = 4
    Status = NativeCompilation.TryCleanup(Ranges, Failure)
    If Not Status Or Ranges(0).FileToken <> 0 Or Ranges(1).FileToken <> 0 Then Code = 5
    CheckCleanup = Code
    Exit Function
Failed:
    CheckCleanup = 1000 + Err.Number
End Function

' Configures immutable counted paths supplied by the native acceptance harness.
Public Function ConfigurePath(ByVal Kind As Long, ByVal Count As Long) As Boolean
    If Kind = 0 Then ConfigurePath = BufferPrimitives.TryResizeBytes(ManifestA, Count, False)
    If Kind = 1 Then ConfigurePath = BufferPrimitives.TryResizeBytes(ManifestB, Count, False)
    If Kind = 2 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputA, Count, False)
    If Kind = 3 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputB, Count, False)
    If Kind = 4 Then ConfigurePath = BufferPrimitives.TryResizeBytes(ClangA, Count, False)
    If Kind = 5 Then ConfigurePath = BufferPrimitives.TryResizeBytes(ClangB, Count, False)
End Function

' Writes one path byte before the request workers can read the immutable inputs.
Public Function SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Byte) As Long
    If Kind = 0 Then ManifestA(Index) = Value
    If Kind = 1 Then ManifestB(Index) = Value
    If Kind = 2 Then OutputA(Index) = Value
    If Kind = 3 Then OutputB(Index) = Value
    If Kind = 4 Then ClangA(Index) = Value
    If Kind = 5 Then ClangB(Index) = Value
End Function

' Selects source emission or native backend execution before publishing test requests.
Public Function ConfigureMode(ByVal Index As Long, ByVal Mode As Long) As Long
    If Index = 0 Then RequestModeA = Mode
    If Index = 1 Then RequestModeB = Mode
End Function

' Runs one complete request and records cleanup independently of success or diagnostics.
Private Sub RunRequest(ByVal Index As Long, ByVal WorkerCount As Long)
    Dim Resources As CompilationRequest.RequestResources
    Dim Stage() As Byte
    Dim Ranges() As NativeCompilation.RangeResult
    Dim DiagnosticPath() As Byte
    Dim Failure As Long
    Dim Status As Boolean
    Dim Mode As Long = 1
    On Error GoTo Failed
    If Index = 0 Then
        If RequestModeA <> 0 Then Mode = RequestModeA
        Results(Index).Completed = CompilationRequest.TryCompile(ManifestA, OutputA, ClangA, Mode, WorkerCount, Resources, Stage, Ranges, Results(Index).Diagnostic, DiagnosticPath)
    Else
        If RequestModeB <> 0 Then Mode = RequestModeB
        Results(Index).Completed = CompilationRequest.TryCompile(ManifestB, OutputB, ClangB, Mode, WorkerCount, Resources, Stage, Ranges, Results(Index).Diagnostic, DiagnosticPath)
    End If
    Results(Index).PathLength = BufferPrimitives.ByteStorageLength(DiagnosticPath)
    If Index = 0 Then Status = BufferPrimitives.TryCopyBytes(DiagnosticA, DiagnosticPath)
    If Index > 0 Then Status = BufferPrimitives.TryCopyBytes(DiagnosticB, DiagnosticPath)
    If Not Status Then Results(Index).ErrorNumber = 7
    If RangeCount(Ranges) > 1 Then
        Results(Index).FirstWork = Ranges(0).State.Work
        Results(Index).SecondWork = Ranges(1).State.Work
        Results(Index).FirstBytes = Ranges(0).State.Text.TotalBytes
        Results(Index).SecondBytes = Ranges(1).State.Text.TotalBytes
        Results(Index).FirstLines = Ranges(0).State.Text.LineCount
        Results(Index).SecondLines = Ranges(1).State.Text.LineCount
        Results(Index).NodeCount = Ranges(0).State.NodeCount
    End If
Cleanup:
    Results(Index).Cleaned = CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure)
    Exit Sub
Failed:
    Results(Index).ErrorNumber = Err.Number
    GoTo Cleanup
End Sub

' Executes the baseline, parallel single request, simultaneous requests or cooperative-stop scenario.
Public Function Run(ByVal Mode As Long) As Long
    Dim First As LongLong
    Dim Second As LongLong
    Dim Status As Long
    On Error GoTo Failed
    If Not ResizeResults(Results, 3, False) Then Run = 1: Exit Function
    If Mode = 1 Then
        Call RunRequest(0, 1)
    ElseIf Mode = 2 Then
        Call RunRequest(0, 2)
    ElseIf Mode = 5 Then
        Call RunRequest(0, 2)
        Call RunRequest(1, 2)
    Else
        First = CallNew RunRequest(0, 2)
        Second = CallNew RunRequest(1, 2)
        If Mode = 4 Then Status = ThreadPrimitives.RequestStop(First)
        Status = ThreadPrimitives.Wait(First, -1)
        Status = ThreadPrimitives.Wait(Second, -1)
        If Mode = 6 Then Call RunRequest(2, 2)
    End If
    If Not Results(0).Cleaned Then Run = 2: Exit Function
    If Mode > 2 And Not Results(1).Cleaned Then Run = 3: Exit Function
    If Mode = 6 And Not Results(2).Cleaned Then Run = 4: Exit Function
    Exit Function
Failed:
    Run = 1000 + Err.Number
End Function

' Writes exact structured results and their counted diagnostic path after all requests have joined.
Public Function WriteObservation(ByVal Index As Long) As Boolean
    Dim Text() As Byte
    Dim Field As Long
    Dim Used As Long
    Dim Value As Long
    Dim Failure As Long
    On Error GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(Text, 256, False) Then Exit Function
    Do While Field < 17
        Value = Observe(Index, Field)
        If Not ByteText.TryAppendInteger(Text, Used, Value) Then Exit Function
        Text(Used) = 44
        Used = Used + 1
        Field = Field + 1
    Loop
    Text(Used) = 10
    Used = Used + 1
    If Not StandardStreams.TryWriteBytes(1, Text, 0, Used, Failure) Then Exit Function
    If Index = 0 Then
        If Not StandardStreams.TryWriteBytes(1, DiagnosticA, 0, BufferPrimitives.ByteStorageLength(DiagnosticA), Failure) Then Exit Function
    Else
        If Not StandardStreams.TryWriteBytes(1, DiagnosticB, 0, BufferPrimitives.ByteStorageLength(DiagnosticB), Failure) Then Exit Function
    End If
    Text(0) = 10
    WriteObservation = StandardStreams.TryWriteBytes(1, Text, 0, 1, Failure)
    Exit Function
Failed:
End Function

' Exposes only structured request outcomes to independent native assertions.
Public Function Observe(ByVal Index As Long, ByVal Field As Long) As Long
    If Field = 0 And Results(Index).Completed Then Observe = 1
    If Field = 1 And Results(Index).Cleaned Then Observe = 1
    If Field = 2 Then Observe = Results(Index).Diagnostic.Kind
    If Field = 3 Then Observe = Results(Index).Diagnostic.Code
    If Field = 4 Then Observe = Results(Index).Diagnostic.Reason
    If Field = 5 Then Observe = Results(Index).Diagnostic.SourceLine
    If Field = 6 Then Observe = Results(Index).Diagnostic.SourceColumn
    If Field = 7 Then Observe = Results(Index).PathLength
    If Field = 8 Then Observe = Results(Index).ErrorNumber
    If Field = 9 Then Observe = Results(Index).FirstWork
    If Field = 10 Then Observe = Results(Index).SecondWork
    If Field = 11 Then Observe = Results(Index).FirstBytes
    If Field = 12 Then Observe = Results(Index).SecondBytes
    If Field = 13 Then Observe = Results(Index).FirstLines
    If Field = 14 Then Observe = Results(Index).SecondLines
    If Field = 15 Then Observe = Results(Index).Diagnostic.Operation
    If Field = 16 Then Observe = Results(Index).NodeCount
End Function
