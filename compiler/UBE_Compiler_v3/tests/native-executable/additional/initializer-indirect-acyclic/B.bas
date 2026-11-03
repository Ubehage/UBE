UBE SOURCE 1 MODULE
Attribute UBE_Name = "B"
Public count As Long = 0
Public y As Long = InitializeValue()
Private Function InitializeValue() As Long
    count = count + 1
    InitializeValue = 7
End Function
