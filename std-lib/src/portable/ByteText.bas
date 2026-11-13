UBE SOURCE 1 MODULE
Attribute UBE_Name = "ByteText"
' Formats exact scalar values into caller-owned counted ASCII bytes.

' Appends signed decimal text atomically, including the minimum LongLong value.
Public Function TryAppendInteger(ByRef Destination() As Byte, ByRef Used As Long, ByVal Value As LongLong) As Boolean
    Dim Scratch(0 To 19) As Byte
    Dim Powers(0 To 18) As LongLong
    Dim Capacity As Long
    Dim Count As Long
    Dim Index As Long
    Dim Digit As Long
    Dim Endpoint As Byte
    Dim Remaining As LongLong
    Dim Twice As LongLong
    Dim Four As LongLong
    Dim Eight As LongLong
    Dim Started As Boolean
    On Error GoTo RuntimeFailure
    If Used < 0 Then TryAppendInteger = FilePrimitives.SetError(5): Exit Function
    Capacity = BufferPrimitives.ByteStorageLength(Destination)
    If Used > Capacity Then TryAppendInteger = FilePrimitives.SetError(9): Exit Function
    If Capacity > 0 Then
        Endpoint = Destination(0)
        Endpoint = Destination(Capacity - 1)
    End If
    Remaining = Value
    If Value < 0 Then Scratch(0) = 45: Count = 1
    If Value > 0 Then Remaining = -Value
    Powers(0) = -1
    Index = 1
    Do While Index < 19
        Twice = Powers(Index - 1) + Powers(Index - 1)
        Four = Twice + Twice
        Eight = Four + Four
        Powers(Index) = Eight + Twice
        Index = Index + 1
    Loop
    Index = 18
    Do While Index >= 0
        Digit = 0
        Do While Remaining <= Powers(Index)
            Remaining = Remaining - Powers(Index)
            Digit = Digit + 1
        Loop
        If Digit <> 0 Or Started Or Index = 0 Then
            Scratch(Count) = Digit + 48
            Count = Count + 1
            Started = True
        End If
        Index = Index - 1
    Loop
    If Count > Capacity - Used Then TryAppendInteger = FilePrimitives.SetError(9): Exit Function
    If BufferPrimitives.CopyByteRange(Scratch, 0, Destination, Used, Count) = False Then TryAppendInteger = False: Exit Function
    Used = Used + Count
    TryAppendInteger = True
    Exit Function
RuntimeFailure:
    TryAppendInteger = False
End Function
