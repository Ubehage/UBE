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

Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long
End Function

Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long
End Function
