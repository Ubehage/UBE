UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"
' Calls a separately compiled source module through its declared identity.
Public Function Main() As Long
    Main = Support.Answer() + 2
End Function
