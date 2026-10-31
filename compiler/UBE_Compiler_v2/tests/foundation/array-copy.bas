Function Main() As Long
    Dim Original() As Byte
    Dim Copy() As Byte
    ReDim Original(1)
    Original(0) = 65
    Original(1) = 255
    Copy = Original
    Original(0) = 66
    Print Copy(0)
    Print Copy(1)
    Copy(1) = 0
    Print Original(1)
    Print Copy(1)
    Main = 0
End Function
