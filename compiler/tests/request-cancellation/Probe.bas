UBE SOURCE 1 MODULE
Attribute UBE_Name = "RequestCancellationProbe"

Private Sub CheckStopped(ByRef Manifest() As Byte, ByRef Output() As Byte, ByRef Result As Long)
    Dim Resources As CompilationRequest.RequestResources
    Dim Report As CompilationRequest.RequestDiagnostic
    Dim Stage() As Byte
    Dim Path() As Byte
    Dim Clang() As Byte
    Dim Ranges() As NativeCompilation.RangeResult
    Dim Failure As Long
    Dim Requested As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Result = 1
    Report.UnavailableDebugInformation = 99
    Requested = ThreadPrimitives.RequestStop(ThreadPrimitives.CurrentId())
    If Requested <> 1 Then Exit Sub
    If CompilationRequest.TryCompile(Manifest, Output, Clang, 1, 1, Resources, Stage, Ranges, Report, Path) Then Exit Sub
    Result = 2
    If Report.Kind <> 12 Or Report.Code <> 104 Or Report.Reason <> 0 Then GoTo Cleanup
    If Report.UnavailableDebugInformation <> 0 Then GoTo Cleanup
    Result = 3
    If Resources.FileToken <> 0 Or Resources.ProcessToken <> 0 Or Resources.StageOwned Then GoTo Cleanup
    If Resources.OutputNameToken <> 0 Or Resources.OutputFileToken <> 0 Or Resources.OutputStageToken <> 0 Then GoTo Cleanup
    If Not CompilerMessages.TryWriteError(Report.Kind, Report.Operation, Report.Code, Report.Reason, Path, Report.SourceLine, Report.SourceColumn) Then GoTo Cleanup
    Result = 0
Cleanup:
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then Result = 4
    Exit Sub
Failed:
    Result = 99
    Status = CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure)
End Sub

Public Function Main() As Long
    Dim Raw() As Byte
    Dim Manifest() As Byte
    Dim Output() As Byte
    Dim Clang() As Byte
    Dim Stage() As Byte
    Dim Path() As Byte
    Dim Ranges() As NativeCompilation.RangeResult
    Dim Resources As CompilationRequest.RequestResources
    Dim Report As CompilationRequest.RequestDiagnostic
    Dim Count As Long
    Dim Failure As Long
    Dim Result As Long
    Dim Worker As LongLong
    Dim Found As Boolean
    Dim Status As Boolean
    On Error GoTo Failed
    Main = 1
    If Not BufferPrimitives.TryResizeBytes(Raw, 131072, False) Then Exit Function
    If Not SystemPrimitives.TryReadCommandLine(Raw, Count, Failure) Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Raw, Count, True) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 1, Manifest, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 2, Output, Found) Then Exit Function
    If Not Found Then Exit Function
    Worker = CallNew CheckStopped(Manifest, Output, Result)
    If Worker = 0 Then Exit Function
    If ThreadPrimitives.Wait(Worker, 10000) <> 1 Then Exit Function
    If Result <> 0 Then Main = 10 + Result: Exit Function
    If ThreadPrimitives.StopRequested() Then Main = 20: Exit Function
    Main = 21
    If CompilationRequest.TryCompile(Manifest, Output, Clang, 1, 1, Resources, Stage, Ranges, Report, Path) Then GoTo Cleanup
    If Report.Kind <> CompilerMessages.LoadError Then
        Status = CompilerMessages.TryWriteError(Report.Kind, Report.Operation, Report.Code, Report.Reason, Path, Report.SourceLine, Report.SourceColumn)
        GoTo Cleanup
    End If
    Main = 0
Cleanup:
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then Main = 22
    Exit Function
Failed:
    Main = 99
    Status = CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure)
End Function
