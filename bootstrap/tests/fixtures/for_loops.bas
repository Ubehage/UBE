Sub Main()
    Dim Index As Long
    For Index = 1 To 5
        If Index = 4 Then
            Exit For
        End If
        Print Index
    Next Index

    Dim Reverse As Long
    For Reverse = 3 To 1 Step -2
        Print Reverse
    Next Reverse

    Dim Counter As Long = 0
    While Counter < 5
        If Counter = 2 Then
            Exit While
        End If
        Counter = Counter + 1
    Wend
    Print Counter
End Sub
