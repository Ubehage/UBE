UBE SOURCE 1 MODULE
Attribute UBE_Name = "Ticket"

Public Function Main() As Long
    Dim Age As Long
    Dim Price As Long
    Age = 12

    ' Children under 16 pay 10. Everyone else pays 20.
    If Age < 16 Then
        Price = 10
    Else
        Price = 20
    End If

    Main = Price
End Function
