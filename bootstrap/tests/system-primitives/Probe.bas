UBE SOURCE 1 MODULE
Attribute UBE_Name = "SystemProbe"
' Observes source calls, preservation, sticky Err and actual inherited streams.
Private Nonzero(9 To 264) As Byte
Public Function Main() As Long
    Dim Data() As Byte
    Dim Small(5 To 5) As Byte
    Dim EmptyBuffer() As Byte
    Dim Count As Long
    Dim Failure As Long
    Dim Written As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(Data, 131072, False) Then Main = 1: Exit Function
    Count = 91
    Small(5) = 77
    If SystemPrimitives.TryReadCommandLine(Small, Count, Failure) Then Main = 2: Exit Function
    If Small(5) <> 77 Or Count <> 91 Or Failure <> 1 Then Main = 3: Exit Function
    If SystemPrimitives.TryReadCommandLine(EmptyBuffer, Count, Failure) Then Main = 19: Exit Function
    If Count <> 91 Or Failure <> 1 Then Main = 20: Exit Function
    If SystemPrimitives.TryReadCommandLine(Data, Count, Count) Then Main = 21: Exit Function
    If Count <> 91 Then Main = 22: Exit Function
    If Not SystemPrimitives.TryReadCommandLine(Nonzero, Count, Failure) Then Main = 23: Exit Function
    If Nonzero(9) <> 34 Then Main = 24: Exit Function
    Status = FilePrimitives.SetError(345)
    If Not SystemPrimitives.TryReadCommandLine(Data, Count, Failure) Then Main = 4: Exit Function
    If Count < 1 Or Count > 131072 Or Failure <> 0 Or Err.Number <> 345 Then Main = 5: Exit Function
    Written = 23
    If SystemPrimitives.TryWriteStandard(3, Data, 0, 1, Written, Failure) Then Main = 6: Exit Function
    If Written <> 0 Or Failure <> 1 Then Main = 7: Exit Function
    If SystemPrimitives.TryWriteStandard(1, Data, -1, 1, Written, Failure) Then Main = 8: Exit Function
    If SystemPrimitives.TryWriteStandard(1, Data, 0, 65537, Written, Failure) Then Main = 9: Exit Function
    If SystemPrimitives.TryWriteStandard(1, Data, 131072, 1, Written, Failure) Then Main = 10: Exit Function
    Written = 88
    If SystemPrimitives.TryWriteStandard(1, Data, 0, 1, Written, Written) Then Main = 11: Exit Function
    If Written <> 88 Then Main = 12: Exit Function
    Status = FilePrimitives.SetError(678)
    If Not SystemPrimitives.TryWriteStandard(1, Data, 0, Count, Written, Failure) Then Main = 13: Exit Function
    If Written <> Count Or Failure <> 0 Or Err.Number <> 678 Then Main = 14: Exit Function
    If Not SystemPrimitives.TryWriteStandard(1, Data, 0, 0, Written, Failure) Then Main = 15: Exit Function
    If Written <> 0 Or Failure <> 0 Then Main = 16: Exit Function
    Small(5) = 33
    If Not SystemPrimitives.TryWriteStandard(2, Small, 0, 1, Written, Failure) Then Main = 17: Exit Function
    If Written <> 1 Or Failure <> 0 Or Err.Number <> 678 Then Main = 18: Exit Function
    Exit Function
Failed:
    Main = 90
End Function
