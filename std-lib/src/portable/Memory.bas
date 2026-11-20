UBE SOURCE 1 MODULE
Attribute UBE_Name = "Memory"
' Requests a full collection and returns the established collection result.
Public Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function
