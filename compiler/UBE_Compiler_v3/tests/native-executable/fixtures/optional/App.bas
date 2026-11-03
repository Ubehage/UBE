UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private observed As Long
Private Sub Change(Optional ByRef first As Long = 10, Optional ByVal amount As Long = 2)
    first = first + amount
    observed = first
End Sub
Function Main() As Long
    Dim a As Long = 1
    Call Change(a)
    Call Change(amount:=3, first:=(a))
    Call Change(, amount:=4)
    If a = 3 AndAlso observed = 14 Then
        Main = 3
    Else
        Main = 99
    End If
End Function
