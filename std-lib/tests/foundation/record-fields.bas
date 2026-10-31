Type Coordinates
    Left As Long
    Right As Long
End Type

Sub SetCoordinates(ByRef Value As Coordinates)
    Value.Left = 12
    Value.Right = 34
End Sub

Function Main() As Long
    Dim Value As Coordinates
    Print Value.Left
    Print Value.Right
    Call SetCoordinates(Value)
    Print Value.Left
    Print Value.Right
    Main = 0
End Function
