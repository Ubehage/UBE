UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConstantBinding"

Private Const Sum As Single = 1.5! + 2.0!
Private Const Quotient As Double = 1 / 2
Private Const Rounded As Long = 2.5
Private Const Printed As String = 0.1!
Private Const NegativeZero As String = -0.0

Public Function Main() As Long
    If Sum <> 3.5! Then Main = 1: Exit Function
    If Quotient <> 0.5 Then Main = 2: Exit Function
    If Rounded <> 2 Then Main = 3: Exit Function
    If Printed <> "0.1" Then Main = 4: Exit Function
    If NegativeZero <> "-0" Then Main = 5: Exit Function
End Function
