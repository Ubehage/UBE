UBE SOURCE 1 MODULE
Attribute UBE_Name = "DebugCapabilityProbe"

' Exercises request metadata through the public APIs without invoking command rendering.
Public Function Main() As Long
    Dim Raw() As Byte
    Dim DefaultManifest() As Byte
    Dim NoneManifest() As Byte
    Dim InvalidManifest() As Byte
    Dim Output() As Byte
    Dim Clang() As Byte
    Dim Stage() As Byte
    Dim Path() As Byte
    Dim Ranges() As NativeCompilation.RangeResult
    Dim Resources As CompilationRequest.RequestResources
    Dim First As CompilationRequest.RequestDiagnostic
    Dim Second As CompilationRequest.RequestDiagnostic
    Dim Count As Long
    Dim Failure As Long
    Dim Found As Boolean
    Dim Status As Boolean
    On Error GoTo Failed
    Main = 1
    If Not BufferPrimitives.TryResizeBytes(Raw, 131072, False) Then Exit Function
    If Not SystemPrimitives.TryReadCommandLine(Raw, Count, Failure) Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Raw, Count, True) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 1, DefaultManifest, Found) Then Exit Function
    If Not Found Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 2, NoneManifest, Found) Then Exit Function
    If Not Found Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 3, InvalidManifest, Found) Then Exit Function
    If Not Found Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 4, Output, Found) Then Exit Function
    If Not Found Then Exit Function
    First.UnavailableDebugInformation = 99
    Main = 10
    If Not CompilationRequest.TryCompile(DefaultManifest, Output, Clang, 1, 1, Resources, Stage, Ranges, First, Path) Then GoTo Finished
    Main = 11
    If First.Kind <> 0 Or First.UnavailableDebugInformation <> 2 Then GoTo Finished
    If First.Operation <> 0 Or First.Code <> 0 Or First.Reason <> 0 Or First.SourceLine <> 0 Or First.SourceColumn <> 0 Then GoTo Finished
    Main = 12
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then Exit Function
    Second.UnavailableDebugInformation = 99
    Main = 20
    If Not CompilationRequest.TryCompileWithContext(NoneManifest, Output, Clang, 1, 1, False, Resources, Stage, Ranges, Second, Path) Then GoTo Finished
    Main = 21
    If Second.Kind <> 0 Or Second.UnavailableDebugInformation <> 0 Then GoTo Finished
    If First.Kind <> 0 Or First.UnavailableDebugInformation <> 2 Then GoTo Finished
    Main = 22
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then Exit Function
    Main = 30
    Status = CompilationRequest.TryCompile(InvalidManifest, Output, Clang, 1, 1, Resources, Stage, Ranges, First, Path)
    If Status Then GoTo Finished
    Main = 31
    If First.Kind = 0 Or First.UnavailableDebugInformation <> 0 Then GoTo Finished
    If Second.Kind <> 0 Or Second.UnavailableDebugInformation <> 0 Then GoTo Finished
    Main = 0
Finished:
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then Main = 40
    Exit Function
Failed:
    Main = 99
    Status = CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure)
End Function
