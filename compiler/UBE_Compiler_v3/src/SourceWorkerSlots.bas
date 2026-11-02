UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceWorkerSlots"

' Compiler-local control state for one bounded source invocation. No managed
' field, capture, callback, payload or dependency on syntax/semantic work.
' Jobs is 1..4, Total is 0..256, canonical source indexes are admitted in order.
' Every successful native ID stays in its scalar slot until confirmed complete.
Type SourceWorkerSlots
    Id0 As LongLong
    Id1 As LongLong
    Id2 As LongLong
    Id3 As LongLong
    Source0 As Long
    Source1 As Long
    Source2 As Long
    Source3 As Long
    Jobs As Long
    Total As Long
    NextSource As Long
    Active As Long
    StopAdmission As Boolean
    PollCursor As Long
    FirstInfrastructureKind As Long
    FirstInfrastructureSource As Long
End Type

' Rootless initialization; invalid requests have no worker admission.
Function TryInitializeSourceWorkerSlots(ByRef Slots As SourceWorkerSlots, ByVal Jobs As Long, ByVal Total As Long) As Boolean
    TryInitializeSourceWorkerSlots = False
    Slots.Id0 = 0
    Slots.Id1 = 0
    Slots.Id2 = 0
    Slots.Id3 = 0
    Slots.Source0 = 0
    Slots.Source1 = 0
    Slots.Source2 = 0
    Slots.Source3 = 0
    Slots.Jobs = 0
    Slots.Total = 0
    Slots.NextSource = 0
    Slots.Active = 0
    Slots.StopAdmission = False
    Slots.PollCursor = 0
    Slots.FirstInfrastructureKind = 0
    Slots.FirstInfrastructureSource = -1
    If Jobs < 1 Or Jobs > 4 Or Total < 0 Or Total > 256 Then
        Exit Function
    End If
    Slots.Jobs = Jobs
    Slots.Total = Total
    TryInitializeSourceWorkerSlots = True
End Function

Function SourceWorkerIdAt(ByRef Slots As SourceWorkerSlots, ByVal Slot As Long) As LongLong
    SourceWorkerIdAt = 0
    If Slot = 0 Then
        SourceWorkerIdAt = Slots.Id0
    End If
    If Slot = 1 Then
        SourceWorkerIdAt = Slots.Id1
    End If
    If Slot = 2 Then
        SourceWorkerIdAt = Slots.Id2
    End If
    If Slot = 3 Then
        SourceWorkerIdAt = Slots.Id3
    End If
End Function

Function SourceWorkerIndexAt(ByRef Slots As SourceWorkerSlots, ByVal Slot As Long) As Long
    SourceWorkerIndexAt = -1
    If Slot = 0 Then
        SourceWorkerIndexAt = Slots.Source0
    End If
    If Slot = 1 Then
        SourceWorkerIndexAt = Slots.Source1
    End If
    If Slot = 2 Then
        SourceWorkerIndexAt = Slots.Source2
    End If
    If Slot = 3 Then
        SourceWorkerIndexAt = Slots.Source3
    End If
End Function

Sub SetSourceWorkerSlot(ByRef Slots As SourceWorkerSlots, ByVal Slot As Long, ByVal Id As LongLong, ByVal SourceIndex As Long)
    If Slot = 0 Then
        Slots.Id0 = Id
        Slots.Source0 = SourceIndex
    End If
    If Slot = 1 Then
        Slots.Id1 = Id
        Slots.Source1 = SourceIndex
    End If
    If Slot = 2 Then
        Slots.Id2 = Id
        Slots.Source2 = SourceIndex
    End If
    If Slot = 3 Then
        Slots.Id3 = Id
        Slots.Source3 = SourceIndex
    End If
End Sub

' Same first-infrastructure-kind policy as RecordSourceSetFailure: later
' same-kind failures choose the smallest associated canonical source index.
' Closing admission never discards an already admitted ID.
Sub RecordSourceWorkerFailure(ByRef Slots As SourceWorkerSlots, ByVal Kind As Long, ByVal SourceIndex As Long)
    If Slots.FirstInfrastructureKind = 0 Then
        Slots.FirstInfrastructureKind = Kind
        Slots.FirstInfrastructureSource = SourceIndex
    Else
        If Slots.FirstInfrastructureKind = Kind And SourceIndex >= 0 Then
            If Slots.FirstInfrastructureSource < 0 Or SourceIndex < Slots.FirstInfrastructureSource Then
                Slots.FirstInfrastructureSource = SourceIndex
            End If
        End If
    End If
    Slots.StopAdmission = True
End Sub

' Caller immediately commits the result of its statically named CallNew target.
' Slot is the outstanding Admit slot returned by NextSourceWorkerAction; no
' managed operation is allowed between successful CallNew and this scalar store.
' Zero means native start failure (2); a positive ID is retained before return.
Sub CommitSourceWorkerAdmission(ByRef Slots As SourceWorkerSlots, ByVal Slot As Long, ByVal Id As LongLong)
    If Id = 0 Then
        Call RecordSourceWorkerFailure(Slots, 2, Slots.NextSource)
        Exit Sub
    End If
    Call SetSourceWorkerSlot(Slots, Slot, Id, Slots.NextSource)
    Slots.NextSource = Slots.NextSource + 1
    Slots.Active = Slots.Active + 1
End Sub

' Actions: 0 idle, 1 admit, 2 confirmed completion, 3 done. Output slot/source
' are borrowed scalar outputs; both are -1 for idle/done. An Admit does not
' start work: the caller supplies its existing static CallNew and commits it.
' AllowAdmission=False pauses new starts while existing workers still drain.
' One action polls at most one issued ID (wait timeout 1ms), requests sticky
' stop after admission closes, and yields while native work remains active.
' False wait/stop is infrastructure 6, never completion. Cancellation is 4.
Function NextSourceWorkerAction(ByRef Slots As SourceWorkerSlots, ByVal CancellationRequested As Boolean, ByVal AllowAdmission As Boolean, ByRef Slot As Long, ByRef SourceIndex As Long) As Long
    NextSourceWorkerAction = 0
    Slot = -1
    SourceIndex = -1
    If CancellationRequested Then
        Call RecordSourceWorkerFailure(Slots, 4, -1)
    End If
    If Slots.Active = 0 Then
        If Slots.StopAdmission Or Slots.NextSource >= Slots.Total Then
            NextSourceWorkerAction = 3
            Exit Function
        End If
    End If
    If AllowAdmission And Slots.StopAdmission = False And Slots.Active < Slots.Jobs And Slots.NextSource < Slots.Total Then
        Dim FreeSlot As Long = 0
        While FreeSlot < Slots.Jobs And SourceWorkerIdAt(Slots, FreeSlot) <> 0
            FreeSlot = FreeSlot + 1
        Wend
        Slot = FreeSlot
        SourceIndex = Slots.NextSource
        NextSourceWorkerAction = 1
        Exit Function
    End If
    If Slots.Active = 0 Then
        Exit Function
    End If
    Dim Checked As Long = 0
    Dim CurrentSlot As Long = Slots.PollCursor
    While Checked < Slots.Jobs And SourceWorkerIdAt(Slots, CurrentSlot) = 0
        CurrentSlot = CurrentSlot + 1
        If CurrentSlot >= Slots.Jobs Then
            CurrentSlot = 0
        End If
        Checked = Checked + 1
    Wend
    Slots.PollCursor = CurrentSlot + 1
    If Slots.PollCursor >= Slots.Jobs Then
        Slots.PollCursor = 0
    End If
    Dim Id As LongLong = SourceWorkerIdAt(Slots, CurrentSlot)
    Dim CanonicalSource As Long = SourceWorkerIndexAt(Slots, CurrentSlot)
    If Slots.StopAdmission Then
        Dim Requested As Boolean = False
        If TryThreadRequestStop(Id, Requested) = False Then
            Call RecordSourceWorkerFailure(Slots, 6, CanonicalSource)
        End If
    End If
    Dim Completed As Boolean = False
    If TryThreadWait(Id, 1, Completed) = False Then
        Call RecordSourceWorkerFailure(Slots, 6, CanonicalSource)
    Else
        If Completed Then
            Call SetSourceWorkerSlot(Slots, CurrentSlot, 0, CanonicalSource)
            Slots.Active = Slots.Active - 1
            Slot = CurrentSlot
            SourceIndex = CanonicalSource
            NextSourceWorkerAction = 2
        End If
    End If
    If Slots.Active > 0 Then
        Call TryThreadYield()
    End If
End Function
