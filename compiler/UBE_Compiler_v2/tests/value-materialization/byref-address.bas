Type Payload
    Bytes() As Byte
End Type

Sub HoldRecord(ByRef Value As Payload)
End Sub

Sub HoldArray(ByRef Value() As Payload)
End Sub

Sub HoldBytes(ByRef Value() As Byte)
End Sub

Function Forward(ByRef Document As Payload, ByRef Tokens() As Payload, ByRef State As Payload) As Long
    Call HoldRecord(Document)
    Call HoldArray(Tokens)
    Call HoldRecord(State)
    Call HoldBytes(Document.Bytes)
    Forward = 17
End Function

Function Main() As Long
    Dim Document As Payload
    Dim Tokens() As Payload
    Dim State As Payload
    Dim Extra() As Byte
    ReDim Extra(0)
    Print Forward(Document, Tokens, State)
    Main = 0
End Function
