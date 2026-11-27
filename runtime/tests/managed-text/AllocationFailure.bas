UBE SOURCE 1 MODULE
Attribute UBE_Name = "AllocationFailure"

Public Function Main() As Long
    Dim Value As String = "retained"
    Dim Other As String = "other root"
    On Error Resume Next
    ' The test-only native allocation wrapper rejects text allocation for this marker.
    Call FilePrimitives.SetError(1234567)
    Value = "replacement"
    If Err.Number <> 7 Then Main = 1: Exit Function
    If Value <> "retained" Then Main = 1: Exit Function
    Call Memory.CollectGarbage()
    If Other <> "other root" Or Value <> "retained" Then Main = 2: Exit Function
    If Err.Number <> 7 Then Main = 3: Exit Function
    Value = "recovered"
    If Value <> "recovered" Or Err.Number <> 7 Then Main = 4: Exit Function
End Function
