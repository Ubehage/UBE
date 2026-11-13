UBE SOURCE 1 MODULE
Attribute UBE_Name = "CaptureProbe"
' Exercises detached aggregate aliases and ordered value snapshots through source CallNew.
Private Gate As Boolean
Private Observed As Long
Private Finished As Boolean
Private Type Pair
    First As Long
    Second As Long
End Type
Private SharedItems(2 To 3) As Pair

' Allocates and replaces a Long array using the ordinary validated storage primitive.
Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

' Holds worker accesses until the originating source frame has returned.
Private Sub AwaitGate()
    Do While Not Gate
        ThreadPrimitives.Yield
    Loop
End Sub

' Mutates a whole record owned by a departed frame.
Private Sub RecordAlias(ByRef Value As Pair)
    AwaitGate
    Value.Second = Value.First + 2
    Observed = Value.Second
End Sub

' Starts a whole-record alias whose storage must outlive this frame.
Private Function StartRecordAlias() As LongLong
    Dim Value As Pair
    Value.First = 81
    StartRecordAlias = CallNew RecordAlias(Value)
End Function

' Replaces an escaping local array descriptor from the worker.
Private Sub ArrayAlias(ByRef Values() As Long)
    AwaitGate
    If Resize(Values, 4, True) = False Then Err.Raise 7
    Observed = Values(0) + 3
End Sub

' Starts a descriptor alias whose nested payload ownership belongs to its final box owner.
Private Function StartArrayAlias() As LongLong
    Dim Values() As Long
    If Resize(Values, 2, False) = False Then Err.Raise 7
    Values(0) = 91
    StartArrayAlias = CallNew ArrayAlias(Values)
End Function

' Reads an indexed alias after its old array payload has been replaced.
Private Sub CellAlias(ByRef Value As Long)
    AwaitGate
    Observed = Value
    Value = Value + 1
End Sub

' The index pin must retain the captured element even after a nonpreserving replacement.
Private Function StartReplacedElement() As LongLong
    Dim Values() As Long
    If Resize(Values, 2, False) = False Then Err.Raise 7
    Values(0) = 101
    StartReplacedElement = CallNew CellAlias(Values(0))
    If Resize(Values, 4, False) = False Then Err.Raise 7
    Values(0) = 999
End Function

' A captured ByVal scalar parameter needs its own escaping storage in this frame.
Private Function StartParameter(ByVal Value As Long) As LongLong
    StartParameter = CallNew CellAlias(Value)
End Function

' Reads a fixed descriptor after its declaring frame returns.
Private Sub FixedArrayAlias(ByRef Values() As Long)
    AwaitGate
    Observed = Values(-2)
    Values(-2) = 777
End Sub

' Captures the complete fixed-array descriptor, not only a single element pin.
Private Function StartFixedArray() As LongLong
    Dim Values(-2 To 1) As Long
    Values(-2) = 151
    StartFixedArray = CallNew FixedArrayAlias(Values)
End Function

' Changes the source while a later CallNew argument is being evaluated.
Private Function ChangeRecord(ByRef Value As Pair) As Long
    Value.First = 999
    ChangeRecord = 7
End Function

' Checks that the earlier ByVal snapshot preceded the later argument's side effect.
Private Sub RecordValue(ByVal Value As Pair, ByVal Suffix As Long)
    AwaitGate
    Observed = Value.First + Suffix
End Sub

' Captures the record before the following argument mutates its source.
Private Function StartOrderedRecord() As LongLong
    Dim Value As Pair
    Value.First = 111
    StartOrderedRecord = CallNew RecordValue(Value, ChangeRecord(Value))
End Function

' Changes the array source during evaluation of a later argument.
Private Function ChangeArray(ByRef Values() As Long) As Long
    Values(0) = 999
    ChangeArray = 8
End Function

' Observes an independent earlier ByVal array snapshot.
Private Sub ArrayValue(ByVal Values() As Long, ByVal Suffix As Long)
    AwaitGate
    Observed = Values(0) + Suffix
End Sub

' Captures the array value before the following argument writes its source.
Private Function StartOrderedArray() As LongLong
    Dim Values() As Long
    If Resize(Values, 2, False) = False Then Err.Raise 7
    Values(0) = 121
    StartOrderedArray = CallNew ArrayValue(Values, ChangeArray(Values))
End Function

' A normal worker return remains successful despite its own handled error.
Private Sub StaleError()
    On Error Resume Next
    Err.Raise 77
End Sub

' Publishes a side effect from an ignored thread identifier.
Private Sub IgnoredChild()
    AwaitGate
    Observed = 131
    Finished = True
End Sub

' Starts a nested source worker without waiting for or retaining its identifier.
Private Sub NestedParent()
    CallNew IgnoredChild()
End Sub

' Checks lifetime, ordering, ignored IDs and isolated stale error state.
Public Function Run() As Long
    Dim Id As LongLong
    Gate = False
    Id = StartRecordAlias()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 83 Then Run = 1: Exit Function
    Gate = False
    Id = StartArrayAlias()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 94 Then Run = 2: Exit Function
    Gate = False
    Id = StartReplacedElement()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 101 Then Run = 3: Exit Function
    Gate = False
    Id = StartOrderedRecord()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 118 Then Run = 4: Exit Function
    Gate = False
    Id = StartOrderedArray()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 129 Then Run = 5: Exit Function
    Err.Clear
    Id = CallNew StaleError()
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Err.Number <> 0 Then Run = 6: Exit Function
    Finished = False
    Id = CallNew NestedParent()
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Run = 7: Exit Function
    Do While Not Finished
        ThreadPrimitives.Yield
    Loop
    If Observed <> 131 Then Run = 8
    Gate = False
    Id = StartParameter(141)
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 141 Then Run = 9: Exit Function
    Gate = False
    Id = StartFixedArray()
    Gate = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 151 Then Run = 10: Exit Function
    SharedItems(2).First = 161
    Id = CallNew CellAlias(SharedItems(2).First)
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Or Observed <> 161 Or SharedItems(2).First <> 162 Then Run = 11
End Function
