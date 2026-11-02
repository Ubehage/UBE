UBE SOURCE 1 MODULE
Attribute UBE_Name = "CallsApp"
Option Explicit
Option Compare Binary
Option Base 0
Public Sub Change(Optional ByRef first As Long = 10, Optional ByVal amount As Long = 2)
    first = first + amount
End Sub
Private Function IsPositive(ByVal value As Long) As Boolean
    IsPositive = value > 0
End Function
Public Sub Main()
    Dim a As Long = 1
    Call Change(a)
    Call Change(amount:=3, first:=(a))
    Call Change(, amount:=4)
    Dim ok As Boolean = IsPositive(a) AndAlso IsPositive(0)
    If ok Then
        While a < 5
            a = a + 1
            Exit While
        Wend
    Else
        Exit Sub
    End If
End Sub
