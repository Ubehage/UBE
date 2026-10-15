Type SharedPair
    Left As Long
    Right As Long
End Type

Function AddPair(ByVal Item As SharedPair) As Long
    AddPair = Item.Left + Item.Right
End Function

Function ModuleMessage(ByVal Value As Long) As String
    If Value = 7 Then
        ModuleMessage = "multi-module"
    Else
        ModuleMessage = "wrong"
    End If
End Function
