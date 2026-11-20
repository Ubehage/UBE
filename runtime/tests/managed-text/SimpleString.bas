UBE SOURCE 1 MODULE
Attribute UBE_Name = "SimpleString"
' Small native diagnostic independent of the full acceptance client's frame size.
Private Function Echo(ByVal Value As String) As String
    Echo = Value
End Function

Public Function Main() As Long
    Dim Value As String
    On Error GoTo Failed
    Value = Echo("Hi")
    If Value <> "Hi" Then Main = 1
    Exit Function
Failed:
    Main = 250
End Function
