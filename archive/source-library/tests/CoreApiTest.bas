UBE SOURCE 1 MODULE
Attribute UBE_Name = "CoreApiTest"

Function Main() As Long
    Dim EmptyValue As Variant = CreateEmptyVariant()
    Dim NullValue As Variant = CreateNullVariant()
    Dim NumberValue As Variant = CreateLongVariant(42)
    Dim Extracted As Long = 0

    Print IsEmpty(EmptyValue)
    Print IsNull(NullValue)
    Print VariantIsEmpty(EmptyValue)
    Print VariantIsNull(NullValue)
    Print TryGetVariantLong(NumberValue, Extracted)
    Print Extracted
    Print StringByteLength("UBE")
    Print StringIsEmpty("")
    Print ConvertLongToString(-123)
    Print ConvertStringToLong("  +456")
    Print StatusSucceeded(0)
    Print StatusFailed(1)
    Main = 0
End Function
