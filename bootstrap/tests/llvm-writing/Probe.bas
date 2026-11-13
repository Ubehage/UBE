UBE SOURCE 1 MODULE
Attribute UBE_Name = "WriterProbe"
' Exercises the real writer against caller-owned private files and visible state.
Private Path() As Byte

' Receives a native UTF-8 test path without exposing a source string dependency.
Public Function ConfigurePath(ByVal Count As Long) As Boolean
    ConfigurePath = BufferPrimitives.TryResizeBytes(Path, Count, False)
End Function

' Supplies each test path byte through the ordinary source ABI.
Public Sub SetPathByte(ByVal Index As Long, ByVal Value As Byte)
    Path(Index) = Value
End Sub

' Runs one independent stateful writer scenario; returns the first failed assertion.
Public Function Run(ByVal Mode As Long, ByVal Seed As Long) As Long
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Text() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Index As Long
    Dim Result As Long
    Dim Ok As Boolean
    On Error GoTo Failed
    If FilePrimitives.TryCreateNew(Path, Token, Failure) = False Then Run = 1: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 2: GoTo Cleanup
    If BufferPrimitives.TryResizeBytes(Text, 65536, False) = False Then Result = 3: GoTo Cleanup
    Do While Index < 65536
        Text(Index) = 64 + Seed
        Index = Index + 1
    Loop
    Ok = FilePrimitives.SetError(5)
    If Mode = 0 Then
        Text(0) = 90
        Text(65535) = 89
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 1, 65534) = False Then Result = 10: GoTo Cleanup
        If LLVMWriter.TryAppendInteger(State, Buffer, Token, -9223372036854775808^) = False Then Result = 11: GoTo Cleanup
        If LLVMWriter.TryEndLine(State, Buffer, Token) = False Then Result = 12: GoTo Cleanup
        If LLVMWriter.TryAppendInteger(State, Buffer, Token, 9223372036854775807^) = False Then Result = 13: GoTo Cleanup
        If LLVMWriter.TryAppendInteger(State, Buffer, Token, 0) = False Then Result = 14: GoTo Cleanup
        If LLVMWriter.TryAppendInteger(State, Buffer, Token, -1) = False Then Result = 15: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 16: GoTo Cleanup
        If State.TotalBytes <> 65578 Or State.Used <> 0 Or State.LineCount <> 1 Then Result = 17: GoTo Cleanup
        If Err.Number <> 5 Or State.Failed Then Result = 18: GoTo Cleanup
    ElseIf Mode = 1 Then
        Index = 0
        Do While Index < 256
            If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 65536) = False Then Result = 20: GoTo Cleanup
            Index = Index + 1
        Loop
        If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 21: GoTo Cleanup
        If State.TotalBytes <> 16777216 Or State.Used <> 0 Then Result = 22: GoTo Cleanup
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 1) Then Result = 23: GoTo Cleanup
        If State.Failure <> 2 Or State.TotalBytes <> 16777216 Then Result = 24: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 25: GoTo Cleanup
    ElseIf Mode = 2 Then
        Index = 0
        Do While Index < 65536
            Text(Index) = 10
            Index = Index + 1
        Loop
        Index = 0
        Do While Index < 3
            If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 65536) = False Then Result = 30: GoTo Cleanup
            Index = Index + 1
        Loop
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 53392) = False Then Result = 31: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 32: GoTo Cleanup
        If State.LineCount <> 250000 Or State.TotalBytes <> 250000 Then Result = 33: GoTo Cleanup
        If LLVMWriter.TryEndLine(State, Buffer, Token) Then Result = 34: GoTo Cleanup
        If State.Failure <> 2 Or State.LineCount <> 250000 Or State.TotalBytes <> 250000 Then Result = 35: GoTo Cleanup
    ElseIf Mode = 3 Then
        Text(2) = 128
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 3) Then Result = 40: GoTo Cleanup
        If State.Failure <> 3 Or State.TotalBytes <> 0 Or State.Used <> 0 Then Result = 41: GoTo Cleanup
        Text(2) = 65
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 3) Then Result = 42: GoTo Cleanup
        If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 43: GoTo Cleanup
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, -1, 1) Then Result = 44: GoTo Cleanup
        If State.Failure <> 3 Or State.TotalBytes <> 0 Then Result = 45: GoTo Cleanup
        If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 46: GoTo Cleanup
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 65536, 1) Then Result = 47: GoTo Cleanup
        If State.Failure <> 3 Or State.TotalBytes <> 0 Then Result = 48: GoTo Cleanup
        If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 49: GoTo Cleanup
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 65536, 0) = False Then Result = 50: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 51: GoTo Cleanup
    ElseIf Mode = 4 Then
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 3) = False Then Result = 60: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, -1) Then Result = 61: GoTo Cleanup
        If State.Failure <> 4 Or State.FileFailure <> 9 Or State.ErrorNumber <> 5 Then Result = 62: GoTo Cleanup
        If State.Used <> 3 Or State.TotalBytes <> 3 Then Result = 63: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 64: GoTo Cleanup
    ElseIf Mode = 5 Then
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 3) = False Then Result = 70: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 71: GoTo Cleanup
        If State.Failure <> 4 Or State.FileFailure <> 16 Or State.ErrorNumber <> 57 Then Result = 72: GoTo Cleanup
        If State.Used <> 0 Or State.TotalBytes <> 3 Then Result = 73: GoTo Cleanup
        If LLVMWriter.TryAppendInteger(State, Buffer, Token, 123) Then Result = 74: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 75: GoTo Cleanup
    ElseIf Mode = 6 Then
        If LLVMWriter.TryAppendSpan(State, Buffer, Token, Text, 0, 3) = False Then Result = 80: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 81: GoTo Cleanup
        If State.Failure <> 4 Or State.FileFailure <> 15 Or State.ErrorNumber <> 57 Then Result = 82: GoTo Cleanup
        If State.Used <> 3 Or State.TotalBytes <> 3 Then Result = 83: GoTo Cleanup
        If LLVMWriter.TryFinish(State, Buffer, Token) Then Result = 84: GoTo Cleanup
    End If
Cleanup:
    If FilePrimitives.TryClose(Token, Failure) = False Then Run = 90: Exit Function
    If Token <> 0 Then Run = 91: Exit Function
    Run = Result
    Exit Function
Failed:
    Result = 99
    GoTo Cleanup
End Function
