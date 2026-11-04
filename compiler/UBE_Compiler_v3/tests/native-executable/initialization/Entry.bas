UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeInitializationFixture"
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function
Function Main() As Long
    Main = 0
End Function
Function TryMakeInitializationCancellation(ByRef Result As SourceCancellation) As Boolean
    Set Result = New SourceCancellation
    TryMakeInitializationCancellation = (Result Is Nothing) = False
End Function
