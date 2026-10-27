UBE SOURCE 1 MODULE
Attribute UBE_Name = "Task0Representative"

Private Const Limit As Long = 4

Private Function DoubleValue(ByVal Value As Long) As Long
    DoubleValue = Value * 2
End Function

Public Sub Main()
    Dim Index As Long
    Index = 1 + 2 * 3
    If Index > Limit Then
        Print "high"
    Else
        While Index < Limit
            Index = Index + 1
        Wend
    End If
    Print DoubleValue(Index)
End Sub
