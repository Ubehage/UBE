UBE SOURCE 1 MODULE
Attribute UBE_Name = "SharedProbeEntry"
Intrinsic Function TryResizeSharedProbeBytes(ByRef Values() As Byte, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSharedProbeBytes.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeSharedProbeKeys(ByRef Values() As ByteKey, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSharedProbeKeys.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeSharedProbeLongs(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSharedProbeLongs.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopySharedProbeLongs(ByRef Destination() As Long, ByRef Original() As Long) As Boolean
Attribute TryCopySharedProbeLongs.UBE_Primitive = "Array.TryCopy"
End Function
Function TryMakeSharedProbeOwner(ByVal Count As Long, ByVal SourceId As Long, ByRef Published As SharedProbeOwner, ByRef Failure As Long) As Boolean
    TryMakeSharedProbeOwner = False
    Failure = 1
    If Count < 0 Or Count > 16384 Then
        Exit Function
    End If
    Failure = 5
    Dim Pending As SharedProbeOwner
    Set Pending = New SharedProbeOwner
    If Pending Is Nothing Then
        Exit Function
    End If
    If TryResizeSharedProbeBytes(Pending.Bytes, Count * 4, False) = False Then
        Exit Function
    End If
    If TryResizeSharedProbeKeys(Pending.Keys, Count, False) = False Then
        Exit Function
    End If
    If TryResizeSharedProbeBytes(Pending.NumericBytes, 19, False) = False Then
        Exit Function
    End If
    If TryResizeSharedProbeBytes(Pending.NameBytes, 7, False) = False Then
        Exit Function
    End If
    Pending.Count = Count
    Pending.SourceId = SourceId
    Set Published = Pending
    Failure = 0
    TryMakeSharedProbeOwner = True
End Function
Function TryFinishSharedProbeOwner(ByVal Owner As SharedProbeOwner, ByRef Failure As Long) As Boolean
    TryFinishSharedProbeOwner = False
    Failure = 5
    If Owner Is Nothing Then
        Failure = 1
        Exit Function
    End If
    If TryOrderByteKeys(Owner.Bytes, Owner.Keys, Owner.Count, 1048576, Owner.Index, Failure) = False Then
        Exit Function
    End If
    Failure = 5
    Dim ArenaWork As ArenaProbeWork
    If TryBuildArenaProbe(Owner.Bytes, Owner.Count, 1048576, 1, 1, Owner.Arena, Failure, ArenaWork) = False Then
        Exit Function
    End If
    Failure = 5
    Dim Half As LongLong = 2147483647
    Half = Half + 1
    Dim Maximum As LongLong = Half * Half
    Maximum = (Maximum - 1) * 2 + 1
    Owner.Maximum = Maximum
    Owner.Minimum = -Maximum - 1
    Owner.Ready = 1
    Failure = 0
    TryFinishSharedProbeOwner = True
End Function
Function TryMakeSharedProbeWork(ByVal Owner As SharedProbeOwner, ByVal Slot As Long, ByRef Published As SharedProbeWork, ByRef Failure As Long) As Boolean
    TryMakeSharedProbeWork = False
    Failure = 5
    If Owner Is Nothing Then
        Failure = 1
        Exit Function
    End If
    If Owner.Ready <> 1 Or Slot < 0 Or Slot > 3 Then
        Failure = 1
        Exit Function
    End If
    Dim Pending As SharedProbeWork
    Set Pending = New SharedProbeWork
    If Pending Is Nothing Then
        Exit Function
    End If
    Set Pending.Owner = Owner
    Pending.Slot = Slot
    Pending.Failure = 5
    Set Published = Pending
    Failure = 0
    TryMakeSharedProbeWork = True
End Function
Sub ProcessSharedProbeWork(ByVal Work As SharedProbeWork)
    Work.Failure = 5
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Exit Sub
    End If
    Dim Answers() As Long
    If TryResizeSharedProbeLongs(Answers, Work.Owner.Count * 2 + 2, False) = False Then
        Exit Sub
    End If
    Dim Round As Long = 0
    While Round < 4
        Dim Requested As Boolean = False
        If TryThreadStopRequested(Requested) = False Then
            Exit Sub
        End If
        If Requested Then
            Work.State = 3
            Exit Sub
        End If
        Dim Index As Long = 0
        While Index < Work.Owner.Count
            Dim Lower As Long = -1
            Dim Matches As Long = -1
            Dim Failure As Long = 5
            If TryFindByteKeyRange(Work.Owner.Bytes, Work.Owner.Keys, Work.Owner.Index, Work.Owner.SourceId + (Index Mod 2), Index * 4, 4, Lower, Matches, Failure) = False Then
                Work.Failure = Failure
                Work.State = 2
                Exit Sub
            End If
            Answers(Index * 2) = Lower
            Answers(Index * 2 + 1) = Lower + Matches
            Index = Index + 1
        Wend
        Dim MissingFirst As Long = -1
        Dim MissingCount As Long = -1
        Dim MissingWidth As Long = 0
        If Work.Owner.Count > 0 Then
            MissingWidth = 4
        End If
        Dim MissingFailure As Long = 5
        If TryFindByteKeyRange(Work.Owner.Bytes, Work.Owner.Keys, Work.Owner.Index, Work.Owner.SourceId + 2, 0, MissingWidth, MissingFirst, MissingCount, MissingFailure) = False Then
            Work.Failure = MissingFailure
            Work.State = 2
            Exit Sub
        End If
        Answers(Work.Owner.Count * 2) = MissingFirst
        Answers(Work.Owner.Count * 2 + 1) = MissingCount
        Round = Round + 1
    Wend
    Dim Numeric As LongLong = 0
    Dim NumericFailure As Long = 5
    If TryDecodeDecimalInteger(Work.Owner.NumericBytes, 0, 19, True, Work.Owner.Minimum, Work.Owner.Maximum, Numeric, NumericFailure) = False Then
        Work.Failure = NumericFailure
        Work.State = 2
        Exit Sub
    End If
    Dim Arithmetic As LongLong = 0
    NumericFailure = 5
    If TryEvaluateInteger(2, 40000, 10000, Work.Owner.Minimum, Work.Owner.Maximum, Arithmetic, NumericFailure) = False Then
        Work.Failure = NumericFailure
        Work.State = 2
        Exit Sub
    End If
    Dim Node As Long = Work.Owner.Arena(0).Root
    Dim ArenaWork As ArenaProbeWork
    Dim Total As LongLong = 0
    While Node >= 0
        Dim Record As ArenaProbeRecord
        Call ReadArenaProbeRecord(Record, Work.Owner.Arena(0).Records(Node), ArenaWork)
        Total = Total + Record.Value
        Node = Record.Left
    Wend
    Dim NameBuffer As ByteBuffer
    Dim NameWork As NameProbeWork
    Dim First As Long = -1
    Dim Count As Long = -1
    Dim NameFailure As Long = 5
    If TryAppendCanonicalProbeName(Work.Owner.NameBytes, 0, 7, 6, True, 32, NameBuffer, First, Count, NameFailure, NameWork) = False Then
        Work.Failure = NameFailure
        Work.State = 2
        Exit Sub
    End If
    Work.Failure = 5
    If TrySnapshotByteBuffer(NameBuffer, Work.FoldedNames) = False Then
        Exit Sub
    End If
    If TryCopySharedProbeLongs(Work.Answers, Answers) = False Then
        Exit Sub
    End If
    Work.NumericValue = Numeric
    Work.ArithmeticValue = Arithmetic
    Work.Total = Total
    Work.Comparisons = 0
    Work.ByteReads = 0
    Work.RecordsRead = ArenaWork.Reads
    Work.NameScalars = NameWork.Scalars
    Work.NameEncoded = NameWork.Encoded
    Work.Failure = 0
    Work.State = 1
End Sub
Function StartSharedProbeWork(ByVal Work As SharedProbeWork) As LongLong
    StartSharedProbeWork = CallNew ProcessSharedProbeWork(Work)
End Function
Function WaitSharedProbeWork(ByVal Id As LongLong) As Boolean
    WaitSharedProbeWork = False
    Dim Completed As Boolean = False
    If TryThreadWait(Id, -1, Completed) = False Then
        Exit Function
    End If
    WaitSharedProbeWork = Completed
End Function
Function StopSharedProbeWork(ByVal Id As LongLong) As Boolean
    StopSharedProbeWork = False
    Dim Requested As Boolean = False
    If TryThreadRequestStop(Id, Requested) = False Then
        Exit Function
    End If
    StopSharedProbeWork = Requested
End Function
Function Main() As Long
    Main = 0
End Function
