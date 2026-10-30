UBE SOURCE 1 MODULE
Attribute UBE_Name = "ReferencedValues"

' Returns a stable value used to verify source-project reference resolution.
Public Function ReferencedValue() As Long
    ReferencedValue = 42
End Function

' This declaration is intentionally private to the referenced project.
Private Function HiddenReferencedValue() As Long
    HiddenReferencedValue = 99
End Function
