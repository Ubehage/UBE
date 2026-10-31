Sub Mutate(ByRef Value As Integer)
    Value = 1
End Sub

Function Main() As Long
    Dim Value As Long = 0
    Call Mutate(Value)
    Main = 0
End Function
