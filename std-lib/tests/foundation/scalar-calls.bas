Sub ChangeCopy(ByVal Value As Long)
    Value = 99
End Sub

Sub ChangeStorage(ByRef Value As Long)
    Value = 9
End Sub

Function Add(ByVal Left As Long, ByVal Right As Long) As Long
    Add = Left + Right
End Function

Function Main() As Long
    Dim Value As Long = 7
    Dim Total As Long = 0
    While Total < 40
        Total = Total + 1
    Wend
    Print Add(Total, 1)
    Call ChangeCopy(Value)
    Print Value
    Call ChangeStorage(Value)
    Print Value
    Main = 0
End Function
