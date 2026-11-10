UBE SOURCE 1 MODULE
Attribute UBE_Name = "QuotedTypes"
' Keeps bracketed nominal types distinct from intrinsic names and dump delimiters.
Public Type [Long]
    Value As Byte
End Type
Public Type [A|B]
    Value As Integer
End Type
' Uses actual nominal fields while unbracketed Long remains the primitive type.
Public Function CheckBracketed(ByVal Seed As Long) As Long
    Dim Custom As [Long]
    Dim Piped As [A|B]
    Dim Primitive As Long = Seed
    Dim Value As Long
    Custom.Value = Seed
    Piped.Value = Seed
    Value = Custom.Value
    If Value <> Primitive Then CheckBracketed = 1: Exit Function
    Value = Piped.Value
    If Value <> Primitive Then CheckBracketed = 2: Exit Function
    CheckBracketed = 0
End Function
