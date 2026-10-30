UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Type Pair
    LeftValue As Long
    RightValue As Long
End Type

Sub Main()
    Dim Source As Pair
    Dim Destination As Pair
    Source.RightValue = 42
    Destination.LeftValue = Source.RightValue
    Print Destination.LeftValue
End Sub
