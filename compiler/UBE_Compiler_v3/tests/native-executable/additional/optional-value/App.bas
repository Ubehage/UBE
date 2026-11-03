UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Measure(Optional ByVal small As Integer = -32768, Optional ByVal wide As Long = 2147483647) As Long
    If small = -32768 AndAlso wide = 2147483647 Then
        Measure = 1
    ElseIf small = 7 AndAlso wide = 2147483647 Then
        Measure = 2
    ElseIf small = -32768 AndAlso wide = -1 Then
        Measure = 4
    Else
        Measure = 100
    End If
End Function
Function Main() As Long
    Main = Measure() + Measure(small:=7) + Measure(wide:=-1)
End Function
