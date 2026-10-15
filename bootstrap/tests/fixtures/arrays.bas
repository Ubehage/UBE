Sub Main()
    Dim Numbers() As Long
    ReDim Numbers(1 To 3)
    Numbers(1) = 10
    Numbers(2) = 20
    Numbers(3) = 30
    ReDim Preserve Numbers(1 To 4)
    Numbers(4) = Numbers(1) + Numbers(2) + Numbers(3)
    Print Numbers(4)
    Print LBound(Numbers)
    Print UBound(Numbers)

    Dim Words() As String
    ReDim Words(1)
    Words(0) = "dynamic"
    Words(1) = "arrays"
    Print Words(0) & " " & Words(1)
End Sub
