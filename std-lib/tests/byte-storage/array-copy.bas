Function Main() As Long
    Dim Original() As Byte
    Dim Copy() As Byte
    ReDim Original(0)
    Original(0) = 65
    Copy = Original
    Original(0) = 66
    Print Copy(0)
    Main = 0
End Function
