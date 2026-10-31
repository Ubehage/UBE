UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScalarOutput"

' Thread IDs need their actual LongLong ABI; Double keeps its scalar ABI too.
Function EmptyFraction() As Double
    Dim Fraction As Double
    EmptyFraction = Fraction
End Function

' Both a Double return slot and a local must have a floating neutral value.
Function Main() As Long
    Dim Id As LongLong = 81
    Dim Fraction As Double
    Print Id
    Print EmptyFraction()
    Main = 0
End Function
