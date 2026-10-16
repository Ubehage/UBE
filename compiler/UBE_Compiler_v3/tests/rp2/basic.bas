UBE SOURCE 1 MODULE
Attribute UBE_Name = "Basic"

#Const Enabled = True
#If Enabled Then
Sub Main()
    Dim message As String = "hello"
    Dim count As Long = &H2A&
End Sub
#Else
this is deliberately invalid inactive text ! ! !
#Unknown text is also ignored while inactive
#End If
