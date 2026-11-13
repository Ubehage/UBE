UBE SOURCE 1 MODULE
Attribute UBE_Name = "ArgumentProbe"
' Observes ordinary ByVal aggregate snapshots, evaluation order and failure cleanup.
Public Type Pair
    Left As Long
    Right As Long
End Type
Private Source() As Byte
Private Entered As Long

' Supplies independently owned record-array storage for retained element aliases.
Private Intrinsic Function ResizePairs(ByRef Values() As Pair, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizePairs.UBE_Primitive = "Array.TryResize"
End Function

' Mutates the original after the earlier record argument must already be copied.
Private Function ChangeRecord(ByRef Value As Pair) As Long
    Value.Left = 99
End Function

' Changes its private record without affecting the original caller's record.
Private Function ObserveRecord(ByVal Value As Pair, ByVal Marker As Long) As Long
    If Value.Left <> 1 Or Value.Right <> 41 Or Marker <> 0 Then Exit Function
    Value.Left = 500
    ObserveRecord = 42
End Function

' Checks left-to-right capture and independent record storage.
Public Function CheckByValRecord(ByVal Seed As Long) As Long
    Dim Value As Pair
    Dim Result As Long
    Value.Left = Seed
    Value.Right = 41
    Result = ObserveRecord(Value, ChangeRecord(Value))
    If Result <> 42 Or Value.Left <> 99 Or Value.Right <> 41 Then CheckByValRecord = 1
End Function

' Replaces original array storage after the earlier ByVal array capture.
Private Function ReplaceArray(ByRef Values() As Byte) As Long
    If Not BufferPrimitives.TryResizeBytes(Values, 1, False) Then ReplaceArray = 1: Exit Function
    Values(0) = 99
End Function

' Resizes its private descriptor and never consumes the caller's descriptor.
Private Function ObserveArray(ByVal Values() As Byte, ByVal Marker As Long) As Long
    If BufferPrimitives.ByteStorageLength(Values) <> 2 Or Marker <> 0 Then Exit Function
    If Values(0) <> 1 Or Values(1) <> 41 Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Values, 1, False) Then Exit Function
    Values(0) = 7
    ObserveArray = 42
End Function

' Checks original-array replacement and callee replacement remain independent.
Public Function CheckByValArray(ByVal Seed As Long) As Long
    Dim Values() As Byte
    Dim Result As Long
    If Not BufferPrimitives.TryResizeBytes(Values, 2, False) Then CheckByValArray = 1: Exit Function
    Values(0) = Seed
    Values(1) = 41
    Result = ObserveArray(Values, ReplaceArray(Values))
    If Result <> 42 Or BufferPrimitives.ByteStorageLength(Values) <> 1 Then CheckByValArray = 2: Exit Function
    If Values(0) <> 99 Then CheckByValArray = 3
End Function

' Replaces the array after an earlier element snapshot and a separate borrowed element.
Private Function ReplacePairs(ByRef Values() As Pair) As Long
    If Not ResizePairs(Values, 1, False) Then ReplacePairs = 1: Exit Function
    Values(0).Left = 99
End Function

' Mutates the original retained element independently from the private record snapshot.
Private Function ObservePinned(ByVal Copy As Pair, ByRef Original As Pair, ByVal Marker As Long) As Long
    If Copy.Left <> 1 Or Original.Left <> 1 Or Marker <> 0 Then Exit Function
    Copy.Left = 500
    If Original.Left <> 1 Then Exit Function
    Original.Left = 7
    If Copy.Left <> 500 Or Original.Right <> 41 Then Exit Function
    ObservePinned = 42
End Function

' Checks that snapshot preparation does not invalidate ordinary retained ByRef aliases.
Public Function CheckByValPinnedRecord(ByVal Seed As Long) As Long
    Dim Values() As Pair
    Dim Result As Long
    If Not ResizePairs(Values, 1, False) Then CheckByValPinnedRecord = 1: Exit Function
    Values(0).Left = Seed
    Values(0).Right = 41
    Result = ObservePinned(Values(0), Values(0), ReplacePairs(Values))
    If Result <> 42 Or Values(0).Left <> 99 Then CheckByValPinnedRecord = 2
End Function

' Prepares one live source block before allocator fault injection begins.
Public Function PrepareArguments(ByVal Seed As Long) As Long
    Entered = 0
    If Not BufferPrimitives.TryResizeBytes(Source, 2, False) Then PrepareArguments = 1: Exit Function
    Source(0) = 10 + Seed
    Source(1) = 31
End Function

' Supplies an observable entry count, so abandoned calls cannot accidentally pass.
Private Function Consume(ByVal Values() As Byte, ByVal Marker As Long) As Long
    Entered = Entered + 1
    If BufferPrimitives.ByteStorageLength(Values) <> 2 Or Marker <> 0 Then Exit Function
    If Values(0) <> 11 Or Values(1) <> 31 Then Exit Function
    Consume = 42
End Function

' Requires both captured arrays before entry and changes neither original source.
Private Function ConsumeTwo(ByVal First() As Byte, ByVal Second() As Byte) As Long
    Entered = Entered + 1
    If First(0) <> 11 Or Second(1) <> 31 Then Exit Function
    ConsumeTwo = 42
End Function

' Two injected allocation failures must abandon argument preparation, then permit recovery.
Public Function CheckByValCopyFailure(ByVal Seed As Long) As Long
    Dim Result As Long = 9
    Result = Consume(Source, 0)
    If Result <> 9 Or Err.Number <> 7 Or Entered <> 0 Then CheckByValCopyFailure = 1: Exit Function
    Result = Consume(Source, 0)
    If Result <> 42 Or Err.Number <> 7 Or Entered <> 1 Or Source(0) <> 10 + Seed Then CheckByValCopyFailure = 2
End Function

' Quota refusal on the second snapshot must release the first before a recovery call.
Public Function CheckByValSecondCopyFailure(ByVal Seed As Long) As Long
    Dim Result As Long = 9
    Result = ConsumeTwo(Source, Source)
    If Result <> 9 Or Err.Number <> 7 Or Entered <> 0 Then CheckByValSecondCopyFailure = 1: Exit Function
    Result = Consume(Source, 0)
    If Result <> 42 Or Err.Number <> 7 Or Entered <> 1 Or Source(0) <> 10 + Seed Then CheckByValSecondCopyFailure = 2
End Function

' Raises after an earlier array snapshot has been successfully allocated.
Private Function RaiseLater() As Long
    Err.Raise 73
End Function

' A handler must observe cleanup before making another allocation under the same quota.
Public Function CheckByValLaterFailure(ByVal Seed As Long) As Long
    Dim Result As Long = 9
    On Error GoTo Handled
    Result = Consume(Source, RaiseLater())
    CheckByValLaterFailure = 1
    Exit Function
Handled:
    If Result <> 9 Or Err.Number <> 73 Or Entered <> 0 Then CheckByValLaterFailure = 2: Exit Function
    Result = Consume(Source, 0)
    If Result <> 42 Or Err.Number <> 73 Or Entered <> 1 Or Source(0) <> 10 + Seed Then CheckByValLaterFailure = 3
End Function

' A callee refused at the depth boundary must not retain the caller's snapshot.
Public Function CheckByValDepthFailure(ByVal Seed As Long) As Long
    Dim Result As Long = 9
    Result = Consume(Source, 0)
    If Result <> 9 Or Err.Number <> 28 Or Entered <> 0 Or Source(0) <> 10 + Seed Then CheckByValDepthFailure = 1
End Function
