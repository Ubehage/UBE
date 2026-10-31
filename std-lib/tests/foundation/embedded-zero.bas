Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Intrinsic Function StringFromByte(ByVal Value As Long) As String
End Function

Function Main() As Long
    Dim Value As String = "A" & StringFromByte(0) & "B"
    Print StringLength(Value)
    Main = 0
End Function
