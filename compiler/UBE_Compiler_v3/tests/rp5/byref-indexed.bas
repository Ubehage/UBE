UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub SetNumber(ByRef Value As Long)
    Value = 42
End Sub

Sub SetName(ByRef Value As String)
    Value = "indexed"
End Sub

Sub Main()
    Dim Numbers() As Long
    Dim Names() As String
    ReDim Numbers(0 To 1)
    ReDim Names(0 To 1)
    Call SetNumber(Numbers(1))
    Call SetName(Names(1))
    Print Numbers(1)
    Print Names(1)
End Sub
