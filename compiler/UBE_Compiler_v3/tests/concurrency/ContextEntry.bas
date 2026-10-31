UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceContextEntry"

' Copies only the reference vector, retaining the same immutable source owners.
Intrinsic Function TryCopySourceOwners(ByRef Destination() As SourceOwner, ByRef Source() As SourceOwner) As Boolean
Attribute TryCopySourceOwners.UBE_Primitive = "Array.TryCopy"
End Function

Function MakeSourceContext(ByRef Inputs() As SourceOwner) As SourceContextWork
    Dim Pending As SourceContextWork
    Set Pending = New SourceContextWork
    If Pending Is Nothing Then
        Exit Function
    End If
    Pending.Failure.Kind = 5
    Pending.Failure.SourceId = -1
    Set Pending.Cancellation = New SourceCancellation
    If Pending.Cancellation Is Nothing Then
        Exit Function
    End If
    If TryCopySourceOwners(Pending.Inputs, Inputs) = False Then
        Exit Function
    End If
    Set MakeSourceContext = Pending
End Function

' Each independent caller supplies one bounded source-work budget.
Sub ProcessSourceContext(ByVal Work As SourceContextWork)
    Work.Failure.Kind = 5
    Work.Failure.SourceId = -1
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Work.State = 2
        Exit Sub
    End If
    If TryParseSources(Work.Inputs, 1, 1048576, 1048576, 1048576, 256, Work.Cancellation, Work.Published, Work.Failure) = False Then
        Work.State = 2
        Exit Sub
    End If
    Work.State = 1
End Sub

Function StartSourceContext(ByVal Work As SourceContextWork) As LongLong
    StartSourceContext = CallNew ProcessSourceContext(Work)
End Function
