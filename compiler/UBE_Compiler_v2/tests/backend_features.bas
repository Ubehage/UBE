Type Pair
    Left As Long
    Right As Long
End Type

Sub SetValue(ByRef Value As Long, ByVal NewValue As Long)
    Value = NewValue
End Sub

Function Add(ByVal Left As Long, ByVal Right As Long) As Long
    Add = Left + Right
End Function

Function Main() As Long
    Dim Values() As Long
    ReDim Values(1)
    Values(0) = 2
    Values(1) = 3
    Dim Item As Pair
    Item.Left = Values(0)
    Call SetValue(Item.Right, Values(1))
    Dim Total As Long = Add(Item.Left, Item.Right)
    While Total < 8
        Total = Total + 1
    Wend
    If Total = 8 Then
        Print "backend-features"
    Else
        Print "wrong"
    End If
    Main = Total
End Function
