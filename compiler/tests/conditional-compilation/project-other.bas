UBE SOURCE 1 MODULE
Attribute UBE_Name = "Other"
Option Explicit
#Const Choice = 8
#If Choice = 8 Then
Public Function ReadValue() As Long
    ReadValue = 42
End Function
#Else
Unselected invalid declaration !!!
#End If
