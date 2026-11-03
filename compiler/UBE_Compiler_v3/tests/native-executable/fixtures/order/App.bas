UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Mark(ByVal n As Long) As Long
    trace = trace * 10 + n
    Mark = n
End Function
Private Function Pair(ByVal first As Long, ByVal second As Long) As Long
    Pair = first * 10 + second
End Function
Private Function Touch() As Boolean
    trace = 99
    Touch = True
End Function
Function Main() As Long
    Dim value As Long = Pair(second:=Mark(2), first:=Mark(1))
    Dim skipped As Boolean = False AndAlso Touch()
    If value = 12 AndAlso trace = 21 Then
        Main = 21
    Else
        Main = 98
    End If
End Function
