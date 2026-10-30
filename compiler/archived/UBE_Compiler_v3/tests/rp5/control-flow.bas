UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Counter As Long
    Dim Result As Long
    Counter = 0
    Result = 0

    While Counter < 3
        If Counter = 0 Then
            Result = Result + 1
        ElseIf Counter = 1 Then
            Result = Result + 2
        Else
            Result = Result + 4
        End If
        Counter = Counter + 1
    Wend

    If Result = 7 Then
        Result = 0
    Else
        Result = 1
    End If
    Print Result
End Sub
