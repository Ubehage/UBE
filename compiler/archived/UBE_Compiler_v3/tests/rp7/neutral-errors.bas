UBE SOURCE 1 MODULE
Attribute UBE_Name = "NeutralErrors"

Sub Main()
    Dim Zero As Long = 0
    Dim InvalidNumber As String = "not-a-number"
    Dim Result As Long

    Call Err.Clear()
    Result = 12 / Zero
    Print Result
    Print Err.Number

    Call Err.Clear()
    Result = InvalidNumber
    Print Result
    Print Err.Number

    Call Err.Clear()
    Print Err.Number
End Sub
