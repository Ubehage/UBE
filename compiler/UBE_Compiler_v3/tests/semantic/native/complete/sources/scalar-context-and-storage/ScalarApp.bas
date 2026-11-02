UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScalarApp"
Option Explicit
Private Const Offset As Long = 2
Private Function AddOffset(ByVal value As Long) As Long
    AddOffset = value + Offset
End Function
Public Function Main() As Long
    Dim small As Integer = 40000 - 10000
    Dim wide As LongLong = 2147483647 + 1
    Dim self As Long = self + Offset
    Main = AddOffset(small)
End Function
