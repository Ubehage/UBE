Function Main() As Long
    Dim Values() As Long
    ReDim Values(1)
    Print Values(0)
    Values(0) = 17
    Values(1) = 29
    ReDim Preserve Values(3)
    Print Values(0)
    Print Values(1)
    Print Values(3)
    Main = 0
End Function
