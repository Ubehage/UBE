UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedValues"

Type RecursiveValue
    Number As Long
    NextValue As RecursiveValue
End Type

Function MakeValue() As RecursiveValue
    MakeValue.Number = 90
    MakeValue.NextValue.Number = 91
End Function

Sub Main()
    Dim First As RecursiveValue
    First.Number = 1
    First.NextValue.Number = 2
    First.NextValue.NextValue.Number = 4

    Dim Independent As RecursiveValue
    Independent = First
    Independent.NextValue.Number = 3
    Independent.NextValue.NextValue.Number = 5
    Print First.NextValue.Number
    Print Independent.NextValue.Number
    Print First.NextValue.NextValue.Number
    Print Independent.NextValue.NextValue.Number

    Dim FixedText As String * 5
    FixedText = "abcdef"
    Print "[" & FixedText & "]"
    FixedText = "xy"
    Print "[" & FixedText & "]"

    Dim DynamicValue As Variant
    DynamicValue = 42
    Dim Converted As Long
    Converted = DynamicValue
    Print Converted

    Dim Logical As Boolean
    Logical = True
    DynamicValue = Logical
    Logical = DynamicValue
    Print Logical

    Dim WideValue As LongLong
    WideValue = 5000000000
    DynamicValue = WideValue
    WideValue = DynamicValue
    Print WideValue

    Dim FloatingValue As Double
    FloatingValue = 12.5
    DynamicValue = FloatingValue
    FloatingValue = DynamicValue
    Print FloatingValue

    Dim VariantText As String
    VariantText = "variant text"
    DynamicValue = VariantText
    VariantText = DynamicValue
    Print VariantText

    DynamicValue = Null
    Converted = 99
    Converted = DynamicValue
    Print Converted

    Dim OriginalItems() As RecursiveValue
    Dim CopiedItems() As RecursiveValue
    ReDim OriginalItems(0 To 0)
    OriginalItems(0).Number = 70
    OriginalItems(0).NextValue.Number = 80
    CopiedItems = OriginalItems
    OriginalItems(0).Number = 71
    OriginalItems(0).NextValue.Number = 81
    Print CopiedItems(0).Number
    Print CopiedItems(0).NextValue.Number

    Dim ReturnedValue As RecursiveValue
    ReturnedValue = MakeValue()
    Print ReturnedValue.Number
    Print ReturnedValue.NextValue.Number
End Sub
