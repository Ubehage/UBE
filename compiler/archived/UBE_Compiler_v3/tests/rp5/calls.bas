UBE SOURCE 1 MODULE
Attribute UBE_Name = "Calls"

Function Add(ByVal LeftValue As Long, ByVal RightValue As Long) As Long
    Add = LeftValue + RightValue
End Function

Function Increment(ByRef Value As Long) As Long
    Value = Value + 1
    Increment = Value
End Function

Function Main() As Long
    Dim Number As Long = 40
    Main = Add(Increment(Number), Increment(Number))
    Print Number
End Function
