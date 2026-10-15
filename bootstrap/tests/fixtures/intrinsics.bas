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
Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long
End Function
Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long
End Function

Sub Main()
    Print CommandArgumentCount()
    Dim Value As String = "abc"
    Print StringLength(Value)
    Print StringByteAt(Value, 1)
    Print StringSlice(Value, 1, 2)
    Print StringIndexOf("abcabc", "bc", 2)
    Print "line" & StringFromByte(33)
    Print LongToString(-42)
    Dim Parts() As String
    ReDim Parts(2)
    Parts(0) = "joined"
    Parts(1) = "-"
    Parts(2) = "text"
    Print StringArrayJoin(Parts, 3)
    Print UnicodeIsLetter(197)
    Print UnicodeIsLetter(128512)
    Print UnicodeSimpleFoldCodePoint(197)
    If CommandArgumentCount() > 0 Then
        Dim Path As String = CommandArgument(0)
        Call WriteAllText(Path, "file-data")
        Print ReadAllText(Path)
    End If
End Sub
