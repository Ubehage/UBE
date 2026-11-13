UBE SOURCE 1 MODULE
Attribute UBE_Name = "DirectoryPrimitives"
' Declares single-directory namespace operations; callers own names, retry and cleanup policy.

' Creates one new directory exclusively and reports an existing name as failure seventeen.
Public Intrinsic Function TryCreate(ByRef PathUtf8() As Byte, ByRef Failure As Long) As Boolean
Attribute TryCreate.UBE_Primitive = "Directory.TryCreate"
End Function

' Removes one empty directory without recursing into any contents.
Public Intrinsic Function TryRemove(ByRef PathUtf8() As Byte, ByRef Failure As Long) As Boolean
Attribute TryRemove.UBE_Primitive = "Directory.TryRemove"
End Function
