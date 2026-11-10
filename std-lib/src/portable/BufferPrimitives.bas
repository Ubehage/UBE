UBE SOURCE 1 MODULE
Attribute UBE_Name = "BufferPrimitives"
' Declares the versioned, representation-aware operations used by counted buffers.

' Returns the number of logical elements without changing the visible error record.
Public Intrinsic Function ByteStorageLength(ByRef Values() As Byte) As Long
Attribute ByteStorageLength.UBE_Primitive = "Array.Length"
End Function

' Copies logical payload bytes with overlap handling and record-only Boolean status.
Public Intrinsic Function CopyByteRange(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean
Attribute CopyByteRange.UBE_Primitive = "Memory.CopyBytes"
End Function
