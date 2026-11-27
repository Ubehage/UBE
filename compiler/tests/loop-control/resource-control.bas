Private Intrinsic Function CreateFile(ByRef Path() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute CreateFile.UBE_Primitive = "File.TryCreateNew"
End Function
Private Intrinsic Function WriteFile(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long) As Boolean
Attribute WriteFile.UBE_Primitive = "File.TryWrite"
End Function
Private Intrinsic Function CloseFile(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute CloseFile.UBE_Primitive = "File.TryClose"
End Function

Public Function Main() As Long
    Dim Token As Long
    Dim Saved As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Index As Long
    Dim Bytes(0 To 1) As Byte
    Dim Closed As Boolean
    On Error GoTo UnexpectedFailure
    ' PATH SETUP
    Bytes(0) = 41
    Bytes(1) = 42
    For Index = 1 To 2
        If Not CreateFile(Path, Token, Failure) Then Main = 2: Exit Function
        Saved = Token
        If Not WriteFile(Token, Bytes, 0, 1, Progress, Failure) Then Main = 3: GoTo Cleanup
        While True
            Do
                Exit Loop
            Loop
        Wend
        Main = 4
        GoTo Cleanup
    Next Index
    If Token <> Saved Or Index <> 1 Then Main = 5: GoTo Cleanup
    If Not WriteFile(Token, Bytes, 1, 1, Progress, Failure) Then Main = 6: GoTo Cleanup
    If Progress <> 1 Then Main = 1
Cleanup:
    Closed = False
    Closed = CloseFile(Token, Failure)
    If Not Closed Then Main = 7: Exit Function
    If Token <> 0 Then Main = 8
    Exit Function
UnexpectedFailure:
    Main = 99
    GoTo Cleanup
End Function
