UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"
Public Type Span
    Start As LongLong
    Count As Long
End Type

' Keeps an already captured element alias on its original storage while replacing the owner.
Private Function ReplaceOwner(ByRef OldValue As Byte, ByRef Values() As Byte) As Long
    If Not BufferPrimitives.TryResizeBytes(Values, 3, True) Then ReplaceOwner = -1: Exit Function
    Values(0) = 19
    ReplaceOwner = OldValue
    OldValue = 21
End Function

' Checked overflow transfers to the handler and preserves the assignment destination.
Private Function OverflowRecovery() As Long
    Dim Limit As Long = 2147483647
    Dim Value As Long = 77
    On Error GoTo Recovered
    Value = Limit + 1
    OverflowRecovery = 1
    Exit Function
Recovered:
    If Err.Number <> 6 Or Value <> 77 Then OverflowRecovery = 2: Exit Function
    Err.Clear
    Value = 42
    If Value <> 42 Or Err.Number <> 0 Then OverflowRecovery = 3
End Function

' Bounds failure transfers to the handler without publishing a failed read value.
Private Function BoundsRecovery() As Long
    Dim Values(0 To 1) As Byte
    Dim Index As Long = 3
    Dim Value As Long = 88
    On Error GoTo Recovered
    Value = Values(Index)
    BoundsRecovery = 1
    Exit Function
Recovered:
    If Err.Number <> 9 Or Value <> 88 Then BoundsRecovery = 2: Exit Function
    Err.Clear
    Values(1) = 42
    If Values(1) <> 42 Or Err.Number <> 0 Then BoundsRecovery = 3
End Function

' Combines independent record copying, alias lifetime and checked failure recovery into one exact oracle.
Public Function Main() As Long
    Dim Original As Span
    Dim Copied As Span
    Dim Values() As Byte
    Dim Observed As Long
    Original.Start = 9223372036854775807^
    Original.Count = 23
    Copied = Original
    Copied.Count = 99
    If Original.Count <> 23 Or Copied.Count <> 99 Or Copied.Start <> Original.Start Then Main = 1: Exit Function
    If Not BufferPrimitives.TryResizeBytes(Values, 1, False) Then Main = 2: Exit Function
    Values(0) = 7
    Observed = ReplaceOwner(Values(0), Values)
    If Observed <> 7 Or Values(0) <> 19 Then Main = 3: Exit Function
    If OverflowRecovery() <> 0 Then Main = 4: Exit Function
    If BoundsRecovery() <> 0 Then Main = 5: Exit Function
    Main = Original.Count + Values(0)
End Function
