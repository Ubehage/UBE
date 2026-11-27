UBE SOURCE 1 MODULE
Attribute UBE_Name = "Runner"
Option Explicit
Public Function Main() As Long
    Dim Value As Gate
    On Error GoTo Failed
    Set Value = New Gate
    If Value Is Nothing Then Main = 1
    Exit Function
Failed:
    Main = 99
End Function
