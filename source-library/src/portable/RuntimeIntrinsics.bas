UBE SOURCE 1 MODULE
Attribute UBE_Name = "RuntimeIntrinsics"

' Private target hooks needed by the first callable UBECore slice. These are
' compiler contracts, not public source-library procedures.
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function

Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function

Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

Intrinsic Function ManagedCollectGarbage() As Long
End Function

Intrinsic Function ManagedVariantEmpty() As Variant
End Function

Intrinsic Function ManagedVariantNull() As Variant
End Function

Intrinsic Function ManagedVariantFromLong(ByVal Value As Long) As Variant
End Function

Intrinsic Function ManagedVariantCopy(ByVal Value As Variant) As Variant
End Function

Intrinsic Function ManagedVariantTag(ByVal Value As Variant) As Long
End Function

Intrinsic Function ManagedVariantGetLong(ByVal Value As Variant, ByRef Result As Long) As Long
End Function
