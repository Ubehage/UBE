UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Mark(ByVal value As Long) As Long
    trace = trace * 10 + value
    Mark = value
End Function
Private Function Pair(ByVal first As Long, ByVal second As Long) As Long
    Pair = first * 10 + second
End Function
Function Main() As Long
    Dim zero As Long = 0
    Dim result As Long = Pair(second:=Mark(1) \ zero, first:=Mark(2))
    If trace = 12 AndAlso result = 20 Then
        Main = 72
    Else
        Main = 99
    End If
End Function
