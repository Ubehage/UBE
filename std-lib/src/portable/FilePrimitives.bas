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

' Obtains physical path spelling from the same owned file handle without reopening it.
Public Intrinsic Function TryFinalPath(ByVal Token As Long, ByRef Destination() As Byte, ByRef Count As Long, ByRef Failure As Long) As Boolean
Attribute TryFinalPath.UBE_Primitive = "File.TryFinalPath"
End Function

' Opens an explicit metadata-only directory owner without enumerating its contents.
Public Intrinsic Function TryOpenDirectory(ByRef PathUtf8() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryOpenDirectory.UBE_Primitive = "File.TryOpenDirectory"
End Function

' Copies twelve opaque physical identity bytes from an existing file or directory owner.
Public Intrinsic Function TryIdentity(ByVal Token As Long, ByRef IdentityBytes() As Byte, ByRef Failure As Long) As Boolean
Attribute TryIdentity.UBE_Primitive = "File.TryIdentity"
End Function

' Queries bounded current byte length without changing the owner's file position.
Public Intrinsic Function TryLength(ByVal Token As Long, ByRef Length As Long, ByRef Failure As Long) As Boolean
Attribute TryLength.UBE_Primitive = "File.TryLength"
End Function

' Deletes one named file, reporting confirmed absence distinctly from other refusal.
Public Intrinsic Function TryDelete(ByRef PathUtf8() As Byte, ByRef Failure As Long) As Boolean
Attribute TryDelete.UBE_Primitive = "File.TryDelete"
End Function

' Replaces a destination by a same-volume move with durable completion, never by cross-volume copying.
Public Intrinsic Function TryReplace(ByRef SourceUtf8() As Byte, ByRef DestinationUtf8() As Byte, ByRef Failure As Long) As Boolean
Attribute TryReplace.UBE_Primitive = "File.TryReplace"
End Function

' Records a recoverable error and returns usable False without raising.
Public Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
