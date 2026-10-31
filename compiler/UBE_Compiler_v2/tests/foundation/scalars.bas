Type SmallValue
    Octet As Byte
    Signed As Integer
End Type

Function EchoByte(ByVal Value As Byte) As Byte
    EchoByte = Value
End Function

Function EchoInteger(ByVal Value As Integer) As Integer
    EchoInteger = Value
End Function

Sub ChangeByte(ByRef Value As Byte)
    Value = 128
End Sub

Function Main() As Long
    Dim Octet As Byte = 255
    Dim Small As Integer = -32768
    Dim Wide As Long = Octet
    Print Octet
    Print Small
    Print Wide
    Print EchoByte(255)
    Print EchoInteger(32767)
    Call ChangeByte(Octet)
    Print Octet
    Dim Original As SmallValue
    Dim Copy As SmallValue
    Original.Octet = 255
    Original.Signed = -32768
    Copy = Original
    Original.Octet = 1
    Print Copy.Octet
    Print Copy.Signed
    Print True
    Main = 0
End Function
