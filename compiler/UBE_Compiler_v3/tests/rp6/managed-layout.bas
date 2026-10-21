UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Type ChainData
    Value As Long
    NextData As ChainData
    Caption As String
End Type

Sub Main()
    Dim Root As ChainData
    Dim Names() As String
    Dim Boxed As Variant
    ReDim Names(0 To 2)
    Root.Value = 42
    Print Root.Value
End Sub
