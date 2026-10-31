Sub WriteByte(ByRef Value As Byte)
    Value = 128
End Sub

Function Main() As Long
    Dim Values() As Byte
    ReDim Values(2)
    Values(0) = 65
    Values(1) = 0
    Values(2) = 255
    ReDim Preserve Values(4)
    Call WriteByte(Values(3))
    Print Values(0)
    Print Values(1)
    Print Values(2)
    Print Values(3)
    Print Values(4)
    Main = 0
End Function
