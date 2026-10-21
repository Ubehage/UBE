UBE SOURCE 1 MODULE
Attribute UBE_Name = "BootstrapIntrinsics"

Intrinsic Function StringLength(ByVal Value As String) As Long
End Function

Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function

Intrinsic Function StringSlice(ByVal Value As String, ByVal Start As Long, ByVal Length As Long) As String
End Function

Intrinsic Function StringIndexOf(ByVal Value As String, ByVal Needle As String, ByVal Start As Long) As Long
End Function

Intrinsic Function StringFromByte(ByVal Value As Long) As String
End Function

Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

Intrinsic Function CommandArgumentCount() As Long
End Function

Intrinsic Function CommandArgument(ByVal Index As Long) As String
End Function

Intrinsic Function ReadAllText(ByVal Path As String) As String
End Function

Intrinsic Function WriteAllText(ByVal Path As String, ByVal Contents As String) As Long
End Function

Intrinsic Function StringArrayJoin(ByRef Values() As String, ByVal Count As Long) As String
End Function

Intrinsic Function CompilerRunTool(ByVal ExecutablePath As String, ByRef Arguments() As String, ByVal ArgumentCount As Long) As Long
End Function

Intrinsic Function CompilerDeleteFile(ByVal Path As String) As Long
End Function

Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long
End Function

Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long
End Function

' Collector entry used by the UBECore Memory module. User programs receive
' the documented CollectGarbage wrapper rather than this implementation hook.
Intrinsic Function ManagedCollectGarbage() As Long
End Function

Intrinsic Function ManagedVariantEmpty() As String
End Function

Intrinsic Function ManagedVariantNull() As String
End Function

Intrinsic Function ManagedVariantFromLong(ByVal Value As Long) As String
End Function

Intrinsic Function ManagedVariantCopy(ByVal Value As String) As String
End Function

Intrinsic Function ManagedVariantTag(ByVal Value As String) As Long
End Function

Intrinsic Function ManagedVariantGetLong(ByVal Value As String, ByRef Result As Long) As Long
End Function
