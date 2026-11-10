UBE SOURCE 1 MODULE
Attribute UBE_Name = "FilePrimitives"
' Declares counted file operations at the portable target boundary.

' Opens a bounded regular byte file and returns its explicit resource owner.
Public Intrinsic Function TryOpen(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Token As Long, ByRef Length As Long, ByRef Failure As Long) As Boolean
Attribute TryOpen.UBE_Primitive = "File.TryOpen"
End Function

' Creates a new writable byte file exclusively, preserving any existing file.
Public Intrinsic Function TryCreateNew(ByRef PathUtf8() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryCreateNew.UBE_Primitive = "File.TryCreateNew"
End Function

' Reads one bounded chunk, publishing destination bytes only after successful I/O.
Public Intrinsic Function TryRead(ByVal Token As Long, ByRef Destination() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef ReadCount As Long, ByRef Failure As Long) As Boolean
Attribute TryRead.UBE_Primitive = "File.TryRead"
End Function

' Writes one bounded chunk and reports only confirmed progress.
Public Intrinsic Function TryWrite(ByVal Token As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef WrittenCount As Long, ByRef Failure As Long) As Boolean
Attribute TryWrite.UBE_Primitive = "File.TryWrite"
End Function

' Flushes a writable owner without closing it.
Public Intrinsic Function TryFlush(ByVal Token As Long, ByRef Failure As Long) As Boolean
Attribute TryFlush.UBE_Primitive = "File.TryFlush"
End Function

' Closes an explicit owner; failed release retains the token for retry.
Public Intrinsic Function TryClose(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryClose.UBE_Primitive = "File.TryClose"
End Function

' Records a recoverable error and returns usable False without raising.
Public Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
