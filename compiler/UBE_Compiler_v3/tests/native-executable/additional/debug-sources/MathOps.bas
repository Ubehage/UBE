UBE SOURCE 1 MODULE
Attribute UBE_Name = "MathOps"
Public hits As Long
Public Function DoubleIt(ByVal value As Long) As Long
    Dim factor As Long = 2
    hits = hits + 1
    DoubleIt = value * factor
End Function
