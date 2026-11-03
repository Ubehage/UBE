UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Weighted(ByVal a As NativeBytes.Octet, ByVal b As NativeBytes.Octet, ByVal c As NativeBytes.Octet, ByVal d As NativeBytes.Octet, ByVal e As NativeBytes.Octet) As Long
    Weighted = NativeBytes.ReadByte(a) + NativeBytes.ReadByte(b) * 2 + NativeBytes.ReadByte(c) * 3 + NativeBytes.ReadByte(d) * 4 + NativeBytes.ReadByte(e) * 5
End Function
Function Main() As Long
    Dim a As NativeBytes.Octet = NativeBytes.CreateByte(1)
    Dim b As NativeBytes.Octet = NativeBytes.CreateByte(2)
    Dim c As NativeBytes.Octet = NativeBytes.CreateByte(3)
    Dim d As NativeBytes.Octet = NativeBytes.CreateByte(4)
    Dim e As NativeBytes.Octet = NativeBytes.CreateByte(5)
    Main = Weighted(a, b, c, d, e)
End Function
