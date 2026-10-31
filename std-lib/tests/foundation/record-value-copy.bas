Type CounterValue
    Count As Long
End Type

Sub ChangeCopy(ByVal Value As CounterValue)
    Value.Count = 50
End Sub

Function Main() As Long
    Dim Original As CounterValue
    Dim Copy As CounterValue
    Original.Count = 7
    Copy = Original
    Original.Count = 9
    Call ChangeCopy(Copy)
    Print Copy.Count
    Print Original.Count
    Main = 0
End Function
