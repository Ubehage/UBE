UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Echo(ByVal value As LongLong) As LongLong
    Echo = value
End Function
Private Sub Increase(ByRef value As LongLong)
    value = value + 1
End Sub
Function Main() As Long
    Dim wide As LongLong = 4294967296
    Dim copy As LongLong = Echo(wide)
    Call Increase(wide)
    If copy = 4294967296 AndAlso wide = 4294967297 Then
        Main = 76
    Else
        Main = 99
    End If
End Function
