Type LeftRecord
    Storage As Byte
End Type

Type RightRecord
    Storage As Byte
End Type

Sub Mutate(ByRef Value As LeftRecord)
    Value.Storage = 1
End Sub

Function Main() As Long
    Dim Value As RightRecord
    Call Mutate(Value)
    Main = 0
End Function
