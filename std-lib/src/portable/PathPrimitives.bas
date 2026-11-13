UBE SOURCE 1 MODULE
Attribute UBE_Name = "PathPrimitives"
' Declares counted target path operations without compiler or containment policy.

' Resolves lexical full-path spelling into caller-provided UTF-8 capacity.
Public Intrinsic Function TryFullPath(ByRef PathUtf8() As Byte, ByRef Destination() As Byte, ByRef Count As Long, ByRef Failure As Long) As Boolean
Attribute TryFullPath.UBE_Primitive = "Path.TryFullPath"
End Function

' Compares complete UTF-8 path spans using target ordinal case-insensitive ordering.
Public Intrinsic Function TryCompareOrdinal(ByRef First() As Byte, ByRef Second() As Byte, ByRef Ordering As Long, ByRef Failure As Long) As Boolean
Attribute TryCompareOrdinal.UBE_Primitive = "Path.TryCompareOrdinal"
End Function

' Reports absent (0), file (1) or directory (2); access failures never imply absence.
Public Intrinsic Function TryKind(ByRef PathUtf8() As Byte, ByRef Kind As Long, ByRef Failure As Long) As Boolean
Attribute TryKind.UBE_Primitive = "Path.TryKind"
End Function
