UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Type Chain
    Value As Long
    NextItem As Chain
End Type

Enum Mode As Long
    ModeFirst = 0
    ModeSecond = 1
End Enum

Sub Main()
    Dim Current As Chain
    Dim Values(0 To 3) As Long
    Dim TextValue As String * 8
    Dim Selected As Mode
    Call Worker(Selected)
    CallNew Worker(Selected)
End Sub
