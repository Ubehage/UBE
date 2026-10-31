Type OwnedBytes
    Data() As Byte
End Type

Sub InitialiseBytes(ByRef Data() As Byte)
    ReDim Data(0)
    Data(0) = 65
End Sub

Function Main() As Long
    Dim Original As OwnedBytes
    Dim Copy As OwnedBytes
    Call InitialiseBytes(Original.Data)
    Copy = Original
    Original.Data(0) = 66
    Print Copy.Data(0)
    Main = 0
End Function
