Public Function Main() As Long
    Dim Narrow As Single
    Dim Wide As Double
    Dim Count As Long
    Dim Small As Integer
    Dim Large As LongLong
    On Error GoTo UnexpectedFailure
    For Narrow = 0.5! To 1.5! Step 0.5!
        Count = Count + 1
    Next Narrow
    If Count <> 3 Or Narrow <> 2! Then Main = 1: Exit Function
    Count = 0
    For Wide = 1.5 To 0.5 Step -0.5
        Count = Count + 1
    Next Wide
    If Count <> 3 Or Wide <> 0 Then Main = 2: Exit Function
    For Narrow = 1! To 3!
        Exit Loop
    Next Narrow
    If Narrow <> 1! Then Main = 3: Exit Function
    For Wide = 1 To 3 Step -0#
        Exit Loop
    Next
    If Wide <> 1 Then Main = 4: Exit Function
    For Small = 1 To 2
        For Large = 2147483648 To 2147483649
            Exit Loop
        Next Large
    Next Small
    If Small <> 1 Or Large <> 2147483648 Then Main = 5: Exit Function
    On Error GoTo 0
    Err.Clear
    For Narrow = 3E38! To 3.4E38! Step 3E38!
        Count = Count + 1
    Next
    If Narrow <> 3E38! Or Err.Number <> 6 Then Main = 6: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 99
End Function
