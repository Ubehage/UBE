UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Mark(ByVal value As Long) As Long
    trace = trace * 10 + value
    Mark = value
End Function
Private Function Combine(ByVal first As Long, ByVal second As Long) As Long
    Combine = first * 10 + second
End Function
Function Main() As Long
    Dim result As Long = Combine(second:=Combine(second:=Mark(2), first:=Mark(1)), first:=Mark(3))
    If trace = 213 AndAlso result = 42 Then
        Main = 71
    Else
        Main = 99
    End If
End Function
