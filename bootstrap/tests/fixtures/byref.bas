Sub Increment(ByRef Value As Long)
    Value = Value + 1
End Sub

Sub Replace(Value As String)
    Value = "updated"
End Sub

Sub IncrementBoth(ByRef LeftValue As Long, ByRef RightValue As Long)
    LeftValue = LeftValue + 1
    RightValue = RightValue + 1
End Sub

Sub Main()
    Dim Number As Long = 41
    Dim Message As String = "old"
    Call Increment(Number)
    Call IncrementBoth(Number, Number)
    Call Replace(Message)
    Print Number
    Print Message
End Sub
