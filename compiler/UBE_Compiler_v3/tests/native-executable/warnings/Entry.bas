UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeWarningFixture"
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function
Function Main() As Long
    Main = 0
End Function
Function TryMakeWarningCancellation(ByRef Result As SourceCancellation) As Boolean
    Dim Ready As SourceCancellation
    Set Ready = New SourceCancellation
    Set Result = Ready
    TryMakeWarningCancellation = (Result Is Nothing) = False
End Function
