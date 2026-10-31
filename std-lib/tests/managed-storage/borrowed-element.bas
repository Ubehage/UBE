Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Sub ReplaceParent(ByRef Borrowed As Byte, ByRef Owner() As Byte)
    ReDim Owner(1)
    Owner(0) = 99
    Call CollectNow()
    Print Borrowed
    Borrowed = 88
    Print Borrowed
    Print Owner(0)
End Sub

Function Main() As Long
    Dim Values() As Byte
    ReDim Values(0)
    Values(0) = 65
    Call ReplaceParent(Values(0), Values)
    Call CollectNow()
    Print Values(0)
    Main = 0
End Function
