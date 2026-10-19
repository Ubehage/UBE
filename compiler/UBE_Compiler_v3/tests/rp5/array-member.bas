UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Type Pair
    LeftValue As Long
    RightValue As Long
End Type

Sub Touch(ByRef Items() As Pair, ByVal Position As Long)
    Items(Position).RightValue = 42
    Items(Position).LeftValue = Items(Position).RightValue
End Sub

Sub Main()
    Dim Items() As Pair
    ReDim Items(0 To 1)
    Call Touch(Items, 1)
    Print Items(1).LeftValue
    Print Items(1).RightValue
End Sub
