UBE SOURCE 1 MODULE
Attribute UBE_Name = "BufferPrimitives"
' Declares the versioned, representation-aware operations used by counted buffers.

' Returns the number of logical elements without changing the visible error record.
Public Intrinsic Function ByteStorageLength(ByRef Values() As Byte) As Long
Attribute ByteStorageLength.UBE_Primitive = "Array.Length"
End Function

' Replaces storage with a zero-based count, preserving the index intersection when requested.
Public Intrinsic Function TryResizeBytes(ByRef Values() As Byte, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute TryResizeBytes.UBE_Primitive = "Array.TryResize"
End Function

' Publishes an independent payload and source bounds only after complete copying succeeds.
Public Intrinsic Function TryCopyBytes(ByRef Destination() As Byte, ByRef Source() As Byte) As Boolean
Attribute TryCopyBytes.UBE_Primitive = "Array.TryCopy"
End Function

' Copies logical payload bytes with overlap handling and record-only Boolean status.
Public Intrinsic Function CopyByteRange(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean
Attribute CopyByteRange.UBE_Primitive = "Memory.CopyBytes"
End Function
