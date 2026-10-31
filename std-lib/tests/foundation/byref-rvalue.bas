Sub Mutate(ByRef Value As Long)
    Value = 1
End Sub

Function Main() As Long
    Call Mutate(2 + 3)
    Main = 0
End Function
