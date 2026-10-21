UBE SOURCE 1 MODULE
Attribute UBE_Name = "ForeignLibrary"

Public Export Function AddValues(ByVal LeftValue As Long, ByVal RightValue As Long) As Long
    AddValues = LeftValue + RightValue
End Function

Public Export Function CreateLeasedValue() As LeasedValue
    Set CreateLeasedValue = New LeasedValue
End Function
