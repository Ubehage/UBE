UBE SOURCE 1 MODULE
Attribute UBE_Name = "DisplayProof"

' Exact bootstrap declarations normally supplied by ByteBuffer/SourceEnvelope.
' The isolated fixture has no dependency on source-language or project policy.
Intrinsic Function ByteStorageLength(ByRef Values() As Byte) As Long
Attribute ByteStorageLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Function Main() As Long
    Main = 0
End Function
