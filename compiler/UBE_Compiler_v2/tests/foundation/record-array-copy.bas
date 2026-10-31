Type Container
    Values() As Byte
End Type

Sub Initialize(ByRef Values() As Byte)
    ReDim Values(0)
    Values(0) = 65
End Sub

Function Main() As Long
    Dim Original As Container
    Dim Copy As Container
    Call Initialize(Original.Values)
    Copy = Original
    Original.Values(0) = 66
    Print Copy.Values(0)
    Print Original.Values(0)
    Main = 0
End Function
