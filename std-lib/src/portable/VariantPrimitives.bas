UBE SOURCE 1 MODULE
Attribute UBE_Name = "VariantPrimitives"
' Exact runtime tag inspection. The argument remains a precise managed root.
Public Intrinsic Function GetTag(ByVal Value As Variant) As Long
Attribute GetTag.UBE_Primitive = "Variant.Tag"
End Function
