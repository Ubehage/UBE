UBE SOURCE 1 MODULE
Attribute UBE_Name = "State"
Public events As Long = 0
Public Function Record(ByVal tag As Long) As Long
    events = events * 10 + tag
    Record = tag
End Function
