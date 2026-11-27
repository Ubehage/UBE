UBE SOURCE 1 MODULE
Attribute UBE_Name = "VariantValues"
' Reflection is ordinary UBE; storage inspection is the sole intrinsic boundary.
Public Function IsEmpty(ByVal Value As Variant) As Boolean
    IsEmpty = VariantPrimitives.GetTag(Value) = 0
End Function

Public Function IsNull(ByVal Value As Variant) As Boolean
    IsNull = VariantPrimitives.GetTag(Value) = 1
End Function

Public Function VarType(ByVal Value As Variant) As Long
    VarType = VariantPrimitives.GetTag(Value)
End Function
