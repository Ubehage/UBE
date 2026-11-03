UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Sub Update(ByRef first As Long, ByRef second As Long)
    first = first + 2
    second = second + 3
End Sub
Private Function Record() As Long
    trace = trace + 1
    Record = 42
End Function
Function Main() As Long
    Dim value As Long = 1
    Call Update(value, value)
    Call Record()
    If value = 6 AndAlso trace = 1 Then
        Main = 70
    Else
        Main = 99
    End If
End Function
