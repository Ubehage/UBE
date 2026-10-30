UBE SOURCE 1 MODULE
Attribute UBE_Name = "UnsupportedForceInlineMain"

ForceInline Function Value() As Long
    Value = 8
End Function

Function Main() As Long
    Main = Value()
End Function
