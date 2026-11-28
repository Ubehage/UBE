UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScannerCancellationProbe"

Private Sub CheckStopped(ByRef Source() As Byte, ByRef Outcome As Long)
    Dim Tokens() As SourceScanner.SourceToken
    Dim Diagnostic As SourceScanner.ScanDiagnostic
    Dim Position As SourceScanner.SourcePosition
    Dim Count As Long = 77
    Dim Requested As Long
    On Error GoTo Failed
    Outcome = 1
    Requested = ThreadPrimitives.RequestStop(ThreadPrimitives.CurrentId())
    If Requested <> 1 Then Exit Sub
    If SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Sub
    If Diagnostic.Code <> 104 Or Diagnostic.Reason <> 0 Then Exit Sub
    If Diagnostic.ByteOffset <> 0 Or Diagnostic.Line <> 1 Or Diagnostic.Column <> 1 Then Exit Sub
    Outcome = 2
    If SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Exit Sub
    If Diagnostic.Code <> 104 Or Count <> 0 Then Exit Sub
    Outcome = 0
    Exit Sub
Failed:
    Outcome = 99
End Sub

Public Function Main() As Long
    Dim Source() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Diagnostic As SourceScanner.ScanDiagnostic
    Dim Count As Long
    Dim Outcome As Long
    Dim Worker As LongLong
    On Error GoTo Failed
    Main = 1
    If Not BufferPrimitives.TryResizeBytes(Source, 1, False) Then Exit Function
    Source(0) = 88
    Worker = CallNew CheckStopped(Source, Outcome)
    If Worker = 0 Then Exit Function
    If ThreadPrimitives.Wait(Worker, 10000) <> 1 Then Exit Function
    If Outcome <> 0 Then Main = 10 + Outcome: Exit Function
    If Not SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Main = 20: Exit Function
    If Count <> 3 Or Tokens(0).Kind <> SourceScanner.WordToken Then Main = 21: Exit Function
    Source(0) = 255
    If SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Main = 22: Exit Function
    If Diagnostic.Code <> 1 Or Diagnostic.Reason <> 1 Then Main = 23: Exit Function
    Main = 0
    Exit Function
Failed:
    Main = 99
End Function
