UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Option Explicit
#Const Choice = 7
#If Choice = 7 Then
Public Function Main() As Long
    Dim Actual As Long
    On Error GoTo UnexpectedFailure
    Actual = -1
    Actual = Other.ReadValue()
    If Actual <> 42 Then Main = 1: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 99
End Function
#Else
Invalid ordinary syntax is ignored here !!!
Asm
#End If
#Else
End Asm
#End If
