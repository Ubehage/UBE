UBE SOURCE 1 MODULE
Attribute UBE_Name = "SupportIntrinsics"

' Private bootstrap hooks used by UBECompilerSupport 0.2.0-v4t4. They remain
' implementation details and are not part of the package's public API.
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function

Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function

Intrinsic Function StringSlice(ByVal Value As String, ByVal StartIndex As Long, ByVal Length As Long) As String
End Function

Intrinsic Function StringFromByte(ByVal Value As Long) As String
End Function

Intrinsic Function CommandArgumentCount() As Long
End Function

Intrinsic Function CommandArgument(ByVal Index As Long) As String
End Function

Intrinsic Function ReadAllText(ByVal Path As String) As String
End Function

Intrinsic Function WriteAllText(ByVal Path As String, ByVal Contents As String) As Long
End Function

Intrinsic Function CompilerRunTool(ByVal ExecutablePath As String, ByRef Arguments() As String, ByVal ArgumentCount As Long) As Long
End Function

Intrinsic Function CompilerDeleteFile(ByVal Path As String) As Long
End Function

Intrinsic Function CompilerMonotonicMilliseconds() As LongLong
End Function

Intrinsic Function CompilerProcessCpuMilliseconds() As LongLong
End Function

Intrinsic Function CompilerPeakWorkingSetBytes() As LongLong
End Function

Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long
End Function

Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long
End Function
