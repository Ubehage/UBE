UBE SOURCE 1 MODULE
Attribute UBE_Name = "FilePrimitives"
Public Mode As Long
Public Reads As Long
Public Closes As Long
Public Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
Public Function TryRead(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long) As Boolean
    Dim Index As Long
    Reads = Reads + 1
    If Reads = 1 Then
        If ThreadPrimitives.RequestStop(ThreadPrimitives.CurrentId()) <> 1 Then Err.Raise 5
        If Mode = 3 Then Failure = 23: Call SetError(57): Exit Function
    End If
    Failure = 0
    Progress = Count
    If Reads = 4 Then Progress = 0
    For Index = 0 To Progress - 1
        Bytes(Offset + Index) = 42
    Next Index
    TryRead = True
End Function
Public Function TryClose(ByRef Token As Long, ByRef Failure As Long) As Boolean
    Closes = Closes + 1
    If Closes = 1 Then Failure = 24: Call SetError(57): Exit Function
    Token = 0
    Failure = 0
    TryClose = True
End Function
Public Function TryOpen(ByRef Path() As Byte, ByVal Maximum As Long, ByRef Token As Long, ByRef Length As Long, ByRef Failure As Long) As Boolean
    Failure = 1
End Function
Public Function TryWrite(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long) As Boolean
    Failure = 1
End Function
Public Function TryFlush(ByVal Token As Long, ByRef Failure As Long) As Boolean
    Failure = 1
End Function
