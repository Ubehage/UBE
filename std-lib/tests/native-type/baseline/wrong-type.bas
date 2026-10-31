Type LeftRecord
    Storage As Byte
End Type

Type RightRecord
    Storage As Byte
End Type

Function Main() As Long
    Dim Left As LeftRecord
    Dim Right As RightRecord
    Left = Right
    Main = 0
End Function
