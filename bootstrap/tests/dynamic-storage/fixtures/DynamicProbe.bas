UBE SOURCE 1 MODULE
Attribute UBE_Name = "DynamicProbe"
' Exercises dynamic leaf values and observable original-storage alias lifetimes.
Public Type Token
    Start As LongLong
    Length As Long
End Type
Private FollowingCalls As Long
Private EnteredCalls As Long

' Grows a UTF-8 source buffer and retained token records, then traverses their spans.
Public Function CheckSourceBuffer(ByVal Seed As Long) As Long
    Dim Bytes() As Byte
    Dim Tokens() As Token
    Dim Status As Boolean
    Dim Index As Long
    Dim Limit As Long
    Dim Sum As Long
    Dim Value As Long
    Status = BufferPrimitives.TryResizeBytes(Bytes, Seed + 1, False)
    Bytes(0) = 97
    Bytes(1) = 195
    Status = BufferPrimitives.TryResizeBytes(Bytes, Seed + 3, True)
    Bytes(2) = 164
    Bytes(3) = 10
    Status = ResizeTokens(Tokens, Seed, False)
    Tokens(0).Start = 0
    Tokens(0).Length = 3
    Status = ResizeTokens(Tokens, Seed + 1, True)
    Tokens(1).Start = 3
    Tokens(1).Length = 1
    Index = Tokens(0).Start
    Limit = Tokens(0).Length
Scan:
    Value = Bytes(Index)
    Sum = Sum + Value
    Index = Index + 1
    If Index < Limit Then GoTo Scan
    If Sum <> 456 Then CheckSourceBuffer = 1: Exit Function
    Index = Tokens(1).Start
    Value = Bytes(Index)
    If Value <> 10 Then CheckSourceBuffer = 2: Exit Function
    CheckSourceBuffer = 0
End Function

' Measures record arrays by logical element count.
Public Intrinsic Function TokenCount(ByRef Values() As Token) As Long
Attribute TokenCount.UBE_Primitive = "Array.Length"
End Function

' Resizes finite-record arrays through the same explicit role as scalar arrays.
Public Intrinsic Function ResizeTokens(ByRef Values() As Token, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTokens.UBE_Primitive = "Array.TryResize"
End Function

' Replaces a record array with an independent copy of the complete source value.
Public Intrinsic Function CopyTokens(ByRef Destination() As Token, ByRef Source() As Token) As Boolean
Attribute CopyTokens.UBE_Primitive = "Array.TryCopy"
End Function

' Establishes a visible error without making a later successful Try operation fail.
Public Sub RaiseFive()
    Err.Raise 5
End Sub

' Copies complete array values through borrowed descriptors of unknown static shape.
Public Sub AssignBorrowed(ByRef Destination() As Byte, ByRef Source() As Byte)
    Destination = Source
End Sub

' Verifies empty values, preservation by index intersection and replacement copies.
Public Function CheckValues(ByVal Seed As Long) As Long
    Dim EmptyBytes() As Byte
    Dim Source(-2 To 2) As Byte
    Dim Destination(8 To 8) As Byte
    Dim Records() As Token
    Dim RecordCopy() As Token
    Dim Status As Boolean
    Dim Value As Long
    Value = BufferPrimitives.ByteStorageLength(EmptyBytes)
    If Value <> 0 Then CheckValues = 1: Exit Function
    RaiseFive
    Status = BufferPrimitives.CopyByteRange(EmptyBytes, 0, EmptyBytes, 0, 0)
    If Status <> True Then CheckValues = 2: Exit Function
    If Err.Number <> 5 Then CheckValues = 3: Exit Function
    Source(-2) = 10
    Source(-1) = 11
    Source(0) = 12
    Source(1) = 13
    Source(2) = 14
    Status = BufferPrimitives.TryResizeBytes(Source, Seed + 3, True)
    If Status <> True Then CheckValues = 4: Exit Function
    Value = Source(0)
    If Value <> 12 Then CheckValues = 5: Exit Function
    Value = Source(2)
    If Value <> 14 Then CheckValues = 6: Exit Function
    Value = Source(3)
    If Value <> 0 Then CheckValues = 7: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Source, 2, True)
    Value = Source(1)
    If Value <> 13 Then CheckValues = 8: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Source, 2, False)
    Value = Source(1)
    If Value <> 0 Then CheckValues = 9: Exit Function
    Source(0) = 97
    Source(1) = 195
    AssignBorrowed Destination, Source
    Destination(0) = 122
    Value = Source(0)
    If Value <> 97 Then CheckValues = 10: Exit Function
    Status = BufferPrimitives.TryCopyBytes(EmptyBytes, Source)
    If Status <> True Then CheckValues = 11: Exit Function
    EmptyBytes(1) = 164
    Value = Source(1)
    If Value <> 195 Then CheckValues = 12: Exit Function
    Status = ResizeTokens(Records, Seed + 1, False)
    If Status <> True Then CheckValues = 13: Exit Function
    Records(1).Start = 44
    Records(1).Length = 2
    Status = CopyTokens(RecordCopy, Records)
    If Status <> True Then CheckValues = 14: Exit Function
    RecordCopy(1).Length = 9
    Value = Records(1).Length
    If Value <> 2 Then CheckValues = 15: Exit Function
    Status = BufferPrimitives.TryResizeBytes(EmptyBytes, 0, True)
    Value = BufferPrimitives.ByteStorageLength(EmptyBytes)
    If Value <> 0 Then CheckValues = 16: Exit Function
    Destination = EmptyBytes
    Value = BufferPrimitives.ByteStorageLength(Destination)
    If Value <> 0 Then CheckValues = 17: Exit Function
    CheckValues = 0
End Function

' Replaces storage while a previously prepared element argument still borrows its old block.
Public Function ReplaceLater(ByRef Values() As Byte) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 2, True)
    If Status = False Then Err.Raise Err.Number
    Values(0) = 9
    ReplaceLater = 0
End Function

' Reads and writes a call-scoped old element alias after another argument replaced its owner.
Public Function ObserveAlias(ByRef OldValue As Byte, ByVal Ignored As Long) As Long
    EnteredCalls = EnteredCalls + 1
    ObserveAlias = OldValue
    OldValue = 11
End Function

' Replaces a descriptor while its receiver is already captured for indexed assignment.
Public Function GrowIndex(ByRef Values() As Byte) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 2, True)
    If Status = False Then Err.Raise Err.Number
    GrowIndex = 1
End Function

' An indexing expression does not retarget the storage path captured before it ran.
Public Function CheckIndexCapture(ByVal Seed As Long) As Long
    Dim Values() As Byte
    Dim Status As Boolean
    Dim Value As Long
    Status = BufferPrimitives.TryResizeBytes(Values, Seed, False)
    Values(0) = 5
    Err.Clear
    Values(GrowIndex(Values)) = 33
    If Err.Number <> 9 Then CheckIndexCapture = 1: Exit Function
    Value = Values(0)
    If Value <> 5 Then CheckIndexCapture = 2: Exit Function
    Value = Values(1)
    If Value <> 0 Then CheckIndexCapture = 3: Exit Function
    CheckIndexCapture = 0
End Function

' Replaces an owner then fails while the caller has a prepared element borrow.
Public Function FailAfterReplace(ByRef Values() As Byte) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 2, True)
    If Status = False Then Err.Raise Err.Number
    Values(0) = 9
    Err.Raise 5
End Function

' Raises after replacing an owner and using its already captured element alias.
Public Function RaiseWithAlias(ByRef OldValue As Byte, ByRef Values() As Byte) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 3, True)
    If Status = False Then Err.Raise Err.Number
    Values(0) = 9
    OldValue = 42
    Err.Raise 5
End Function

' Releases owned local dynamic storage on the explicit FAIL return path.
Public Sub AllocateAndRaise(ByVal Count As Long)
    Dim LocalValues() As Byte
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(LocalValues, Count, False)
    If Status = False Then Err.Raise Err.Number
    LocalValues(0) = 1
    Err.Raise 5
End Sub

' Exercises failed argument preparation and repeated automatic local cleanup.
Public Function CheckCleanup(ByVal Seed As Long) As Long
    Dim Values() As Byte
    Dim Status As Boolean
    Dim Result As Long = 77
    Dim Value As Long
    Dim Passes As Long
    EnteredCalls = 0
    Status = BufferPrimitives.TryResizeBytes(Values, Seed, False)
    Values(0) = 5
    Result = ObserveAlias(Values(0), FailAfterReplace(Values))
    If Result <> 77 Then CheckCleanup = 1: Exit Function
    If EnteredCalls <> 0 Then CheckCleanup = 2: Exit Function
    Value = Values(0)
    If Value <> 9 Then CheckCleanup = 3: Exit Function
    Values(0) = FailAfterReplace(Values)
    Value = Values(0)
    If Value <> 9 Then CheckCleanup = 5: Exit Function
    Result = RaiseWithAlias(Values(0), Values)
    If Result <> 77 Then CheckCleanup = 6: Exit Function
    Value = Values(0)
    If Value <> 9 Then CheckCleanup = 7: Exit Function
Again:
    AllocateAndRaise Seed
    Passes = Passes + 1
    If Passes < 20 Then GoTo Again
    If Err.Number <> 5 Then CheckCleanup = 4: Exit Function
    CheckCleanup = 0
End Function

' Replaces the owning descriptor from inside a callee without retargeting its element alias.
Public Function ReplaceInside(ByRef OldValue As Byte, ByRef Values() As Byte) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 3, True)
    If Status = False Then Err.Raise Err.Number
    Values(0) = 19
    ReplaceInside = OldValue
    OldValue = 21
End Function

' Prepares a new value while a destination-element address belongs to old storage.
Public Function ReplaceForAssignment(ByRef Values() As Byte) As Byte
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(Values, 4, True)
    If Status = False Then Err.Raise Err.Number
    Values(0) = 29
    ReplaceForAssignment = 31
End Function

' Self-copy still creates a replacement value while a live alias pins the original.
Public Function SelfReplace(ByRef OldValue As Byte, ByRef Values() As Byte) As Long
    Values = Values
    Values(0) = 39
    SelfReplace = OldValue
    OldValue = 41
End Function

' Observes replacement during later arguments, callees, assignment RHS and self-copy.
Public Function CheckPins(ByVal Seed As Long) As Long
    Dim Values() As Byte
    Dim Status As Boolean
    Dim Result As Long
    Dim Value As Long
    Status = BufferPrimitives.TryResizeBytes(Values, Seed, False)
    Values(0) = 5
    Result = ObserveAlias(Values(0), ReplaceLater(Values))
    If Result <> 5 Then CheckPins = 1: Exit Function
    Value = Values(0)
    If Value <> 9 Then CheckPins = 2: Exit Function
    Result = ReplaceInside(Values(0), Values)
    If Result <> 9 Then CheckPins = 3: Exit Function
    Value = Values(0)
    If Value <> 19 Then CheckPins = 4: Exit Function
    Values(0) = ReplaceForAssignment(Values)
    Value = Values(0)
    If Value <> 29 Then CheckPins = 5: Exit Function
    Result = SelfReplace(Values(0), Values)
    If Result <> 29 Then CheckPins = 6: Exit Function
    Value = Values(0)
    If Value <> 39 Then CheckPins = 7: Exit Function
    CheckPins = 0
End Function
