UBE SOURCE 1 MODULE
Attribute UBE_Name = "Variants"

' Creates a Variant in its Empty state.
Public Function CreateEmptyVariant() As Variant
    CreateEmptyVariant = ManagedVariantEmpty()
End Function

' Creates a Variant in its Null state.
Public Function CreateNullVariant() As Variant
    CreateNullVariant = ManagedVariantNull()
End Function

' Creates a Variant containing a Long value.
Public Function CreateLongVariant(ByVal Value As Long) As Variant
    CreateLongVariant = ManagedVariantFromLong(Value)
End Function

' Returns an independent Variant container with the same semantic value.
Public Function CopyVariant(ByVal Value As Variant) As Variant
    CopyVariant = ManagedVariantCopy(Value)
End Function

' Returns 1 when Value is Empty and 0 otherwise.
Public Function VariantIsEmpty(ByVal Value As Variant) As Long
    If ManagedVariantTag(Value) = 0 Then
        VariantIsEmpty = 1
    Else
        VariantIsEmpty = 0
    End If
End Function

' Returns 1 when Value is Null and 0 otherwise.
Public Function VariantIsNull(ByVal Value As Variant) As Long
    If ManagedVariantTag(Value) = 1 Then
        VariantIsNull = 1
    Else
        VariantIsNull = 0
    End If
End Function

' Copies a contained Long into Result and returns 1. It returns 0 for an
' incompatible tag and leaves Result unchanged.
Public Function TryGetVariantLong(ByVal Value As Variant, ByRef Result As Long) As Long
    TryGetVariantLong = ManagedVariantGetLong(Value, Result)
End Function
