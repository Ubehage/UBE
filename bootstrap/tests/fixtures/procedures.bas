Function Add(ByVal LeftValue As Long, ByVal RightValue As Long) As Long
    Add = LeftValue + RightValue
End Function

Sub Show(ByVal Value As Long)
    Print Value
End Sub

Sub Main()
    Dim Answer As Long = Add(20, 22)
    Call Show(Answer)
End Sub
