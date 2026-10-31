Sub Consume(ByVal Values() As Byte)
    Values(0) = 88
    Print Values(0)
    ReDim Values(2)
    Print Values(2)
End Sub

Function Main() As Long
    Dim Values() As Byte
    ReDim Values(0)
    Values(0) = 65
    Call Consume(Values)
    Print Values(0)
    Main = 0
End Function
