UBE SOURCE 1 MODULE
Attribute UBE_Name = "BackendCancellationProbe"

Private Sub RunTool(ByRef Application() As Byte, ByRef Command() As Byte, ByRef Stage() As Byte, ByRef LogPath() As Byte, ByVal StopBefore As Boolean, ByRef Outcome As Long)
    Dim FileToken As Long
    Dim ProcessToken As Long
    Dim Failure As Long
    Dim ExitCode As Long
    Dim Status As Boolean
    Dim Requested As Long
    On Error GoTo Failed
    If StopBefore Then Requested = ThreadPrimitives.RequestStop(ThreadPrimitives.CurrentId())
    Status = NativeBackend.TryRun(Application, Command, Stage, LogPath, FileToken, ProcessToken, Failure, ExitCode)
    Outcome = Failure
    If Status Then Outcome = -1
    If FileToken <> 0 Or ProcessToken <> 0 Then Outcome = 900
    Exit Sub
Failed:
    Outcome = 901
End Sub

Public Function Main() As Long
    Dim Raw() As Byte
    Dim Application() As Byte
    Dim Recovery() As Byte
    Dim Command() As Byte
    Dim Stage() As Byte
    Dim LogPath() As Byte
    Dim RecoveryLog() As Byte
    Dim Marker() As Byte
    Dim Mode() As Byte
    Dim Count As Long
    Dim Failure As Long
    Dim Kind As Long
    Dim Outcome As Long
    Dim Recovered As Long
    Dim Found As Boolean
    Dim Worker As LongLong
    Dim Started As LongLong
    Dim Current As LongLong
    Dim Status As Long
    Dim StopBefore As Boolean
    On Error GoTo Failed
    Main = 1
    If Not BufferPrimitives.TryResizeBytes(Raw, 131072, False) Then Exit Function
    If Not SystemPrimitives.TryReadCommandLine(Raw, Count, Failure) Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Raw, Count, True) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 1, Application, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 2, Recovery, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 3, Stage, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 4, LogPath, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 5, RecoveryLog, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 6, Marker, Found) Then Exit Function
    If Not WindowsArguments.TryReadArgument(Raw, 7, Mode, Found) Then Exit Function
    If Not Found Then Exit Function
    ' Explicit application selects the executable; this valid argv[0] is unused by the fixture.
    If Not BufferPrimitives.TryResizeBytes(Command, 1, False) Then Exit Function
    Command(0) = 112
    StopBefore = Mode(0) = 49
    If Not SystemPrimitives.TryMonotonicMilliseconds(Started, Failure) Then Exit Function
    Worker = CallNew RunTool(Application, Command, Stage, LogPath, StopBefore, Outcome)
    If Worker = 0 Then Main = 2: Exit Function
    If Not StopBefore Then
        Do
            If Not PathPrimitives.TryKind(Marker, Kind, Failure) Then Main = 3: Exit Function
            If Kind = 1 Then Exit Do
            If Not SystemPrimitives.TryMonotonicMilliseconds(Current, Failure) Then Exit Function
            If Current - Started > 10000 Then Main = 4: Exit Function
            Call ThreadPrimitives.Yield()
        Loop
        Status = ThreadPrimitives.RequestStop(Worker)
        If Status <> 1 Then Main = 5: Exit Function
    End If
    Status = ThreadPrimitives.Wait(Worker, 10000)
    If Status <> 1 Then Main = 6: Exit Function
    If Outcome <> 104 Then Main = 7: Exit Function
    If ThreadPrimitives.StopRequested() Then Main = 8: Exit Function
    Call RunTool(Recovery, Command, Stage, RecoveryLog, False, Recovered)
    If Recovered <> -1 Then Main = 9: Exit Function
    Main = 0
    Exit Function
Failed:
    Main = 99
End Function
