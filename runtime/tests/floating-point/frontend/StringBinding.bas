UBE SOURCE 1 MODULE
Attribute UBE_Name = "StringBinding"

Private Function EchoText(ByVal Value As String) As String
    EchoText = Value
End Function

Private Function EchoNumber(ByVal Value As Double) As Double
    EchoNumber = Value
End Function

Public Function Main() As Long
    Dim Number As Double
    Dim Small As Single
    Dim TextValue As String
    On Error Resume Next
    Number = EchoText(" 1.5 ")
    If Number <> 1.5 Then Main = 1: Exit Function
    TextValue = Number
    If TextValue <> "1.5" Then Main = 2: Exit Function
    Number = EchoNumber(-0.0)
    TextValue = Number
    If TextValue <> "-0" Then Main = 3: Exit Function
    Small = EchoText("0.1")
    TextValue = Small
    If TextValue <> "0.1" Then Main = 4: Exit Function
    Number = EchoNumber(1.5)
    Number = EchoText("Infinity")
    If Number <> 1.5 Then Main = 5: Exit Function
    If Err.Number <> 13 Then Main = 6: Exit Function
    Number = EchoText("NaN")
    If Number <> 1.5 Then Main = 7: Exit Function
    If Err.Number <> 13 Then Main = 8: Exit Function
    TextValue = Number
    If TextValue <> "1.5" Then Main = 9: Exit Function
    If Err.Number <> 13 Then Main = 10: Exit Function
    Number = EchoText("1.2x")
    If Number <> 1.5 Then Main = 11: Exit Function
    If Err.Number <> 13 Then Main = 12: Exit Function
End Function
