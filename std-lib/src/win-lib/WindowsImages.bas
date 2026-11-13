UBE SOURCE 1 MODULE
Attribute UBE_Name = "WindowsImages"
' Checks bounded Windows executable framing using counted reads and explicit file ownership.

' Reads a complete requested span; a successful zero-length transfer cannot stall this loop.
Private Function ReadExact(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Count As Long, ByRef Failure As Long) As Boolean
    Dim Offset As Long
    Dim Progress As Long
    On Error GoTo Failed
    Do While Offset < Count
        If Not FilePrimitives.TryRead(Token, Bytes, Offset, Count - Offset, Progress, Failure) Then Exit Function
        If Progress <= 0 Or Progress > Count - Offset Then
            Failure = 6
            ReadExact = FilePrimitives.SetError(57)
            Exit Function
        End If
        Offset = Offset + Progress
    Loop
    ReadExact = True
    Exit Function
Failed:
    Failure = 1
End Function

' Tests one byte flag without requiring integral bitwise operators in the bootstrap subset.
Private Function HasFlag(ByVal Value As Long, ByVal Flag As Long) As Boolean
    Dim Pair As Long
    Pair = Flag + Flag
    Do While Value >= Pair
        Value = Value - Pair
    Loop
    HasFlag = Value >= Flag
End Function

' Accepts a bounded AMD64 PE32+ executable header, closes its owner, and retains failed-close tokens.
Public Function TryCheckAMD64Executable(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Bytes() As Byte
    Dim Length As Long
    Dim Offset As LongLong
    Dim Index As Long
    Dim Shift As Long
    Dim Position As Long
    Dim Request As Long
    Dim CloseFailure As Long
    Dim PrimaryError As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Token <> 0 Then Failure = 1: TryCheckAMD64Executable = FilePrimitives.SetError(5): Exit Function
    If MaximumBytes < 90 Then Failure = 1: TryCheckAMD64Executable = FilePrimitives.SetError(5): Exit Function
    If Not FilePrimitives.TryOpen(PathUtf8, MaximumBytes, Token, Length, Failure) Then Exit Function
    If Length < 90 Then GoTo InvalidImage
    If Not BufferPrimitives.TryResizeBytes(Bytes, 65536, False) Then Failure = 8: GoTo Cleanup
    If Not ReadExact(Token, Bytes, 64, Failure) Then GoTo Cleanup
    If Bytes(0) <> 77 Or Bytes(1) <> 90 Then GoTo InvalidImage
    Index = 63
    Do While Index >= 60
        Shift = 0
        Do While Shift < 8
            Offset = Offset + Offset
            Shift = Shift + 1
        Loop
        Offset = Offset + Bytes(Index)
        Index = Index - 1
    Loop
    If Offset < 64 Or Offset > Length - 26 Then GoTo InvalidImage
    Position = 64
    Do While Position < Offset
        If Offset - Position > 65536 Then
            Request = 65536
        Else
            Request = Offset - Position
        End If
        If Not ReadExact(Token, Bytes, Request, Failure) Then GoTo Cleanup
        Position = Position + Request
    Loop
    If Not ReadExact(Token, Bytes, 26, Failure) Then GoTo Cleanup
    If Bytes(0) <> 80 Or Bytes(1) <> 69 Or Bytes(2) <> 0 Or Bytes(3) <> 0 Then GoTo InvalidImage
    If Bytes(4) <> 100 Or Bytes(5) <> 134 Then GoTo InvalidImage
    If Bytes(24) <> 11 Or Bytes(25) <> 2 Then GoTo InvalidImage
    If Not HasFlag(Bytes(22), 2) Then GoTo InvalidImage
    If HasFlag(Bytes(23), 32) Then GoTo InvalidImage
    Status = True
    GoTo Cleanup
InvalidImage:
    Failure = 16
    Status = FilePrimitives.SetError(5)
Cleanup:
    PrimaryError = Err.Number
    If Not FilePrimitives.TryClose(Token, CloseFailure) Then
        If Failure = 0 Then Failure = CloseFailure: Exit Function
    End If
    If Failure <> 0 Then
        Status = FilePrimitives.SetError(PrimaryError)
        Exit Function
    End If
    TryCheckAMD64Executable = Status
    Exit Function
Failed:
    Failure = 1
    Status = False
    GoTo Cleanup
End Function
