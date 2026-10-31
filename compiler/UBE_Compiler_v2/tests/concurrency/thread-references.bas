UBE SOURCE 1 MODULE
Attribute UBE_Name = "ThreadReferences"

' Actual UBE capture, cooperative stop and shared-reference lifetime controls.

' Mutates only this worker's output and observes its sticky cooperative stop.
Sub HoldOwner(ByVal Owner As ByteOwner)
    Dim Requested As Boolean = False
    If TryCurrentThreadId(Owner.WorkerId) = False Then
        Owner.Count = -2
        Exit Sub
    End If
    Owner.Count = 89
    Call RecordErrorNumber(91)
    While Requested = False
        If TryThreadStopRequested(Requested) = False Then
            Owner.Count = -1
            Exit Sub
        End If
        Call TryThreadYield()
    Wend
    Owner.Count = 97
End Sub

' CallNew captures one shared identity and returns its admitted program ID.
Function StartOwnerWork(ByVal Owner As ByteOwner) As LongLong
    StartOwnerWork = CallNew HoldOwner(Owner)
End Function

' Finite waits, stop and join use the ordinary library declarations.
Function Main() As Long
    Dim Owner As ByteOwner
    Set Owner = New ByteOwner
    Dim Id As LongLong = StartOwnerWork(Owner)
    If Id = 0 Then
        Main = 1
        Exit Function
    End If
    While Owner.Count <> 89
        Call TryThreadYield()
    Wend
    Dim Completed As Boolean = True
    Dim WaitStatus As Boolean = TryThreadWait(Id, 0, Completed)
    Dim TimedOut As Boolean = Completed = False
    Dim Requested As Boolean = False
    Dim StopStatus As Boolean = TryThreadRequestStop(Id, Requested)
    If TryThreadWait(Id, -1, Completed) = False Or Completed = False Then
        Main = 2
        Exit Function
    End If
    If WaitStatus = False Or TimedOut = False Or StopStatus = False Or Requested = False Or Owner.Count <> 97 Then
        Main = 3
        Exit Function
    End If
    Print Owner.Count
    Owner.Trace = 0
    Dim ArgumentId As LongLong = StartArgumentWork(Owner)
    If ArgumentId = 0 Then
        Main = 4
        Exit Function
    End If
    If TryThreadWait(ArgumentId, -1, Completed) = False Or Completed = False Then
        Main = 5
        Exit Function
    End If
    Print Owner.Count
    Print Owner.Trace
    Print Owner.WorkerId
    Dim Fraction As Double
    Call CaptureArguments(Owner, 4, 5, 3, 4, True, 81, Fraction)
    Print Owner.Count
    CallNew SignalNoArguments()
    Main = 0
End Function

' Creates source-sized value storage behind a single reference identity.
Function MakeOwner(ByVal Length As Long) As ByteOwner
    Dim Owner As ByteOwner
    Set Owner = New ByteOwner
    If TryResizeByteStorage(Owner.Data, Length, False) = False Then
        Exit Function
    End If
    Owner.Data(0) = 7
    If Length > 1 Then
        Owner.Data(Length - 1) = 11
    End If
    Set Owner.Link = Owner
    Set MakeOwner = Owner
End Function

' A positive copy-observer control executes ordinary ByVal array copying.
Sub ReadOwnerBytes(ByVal Data() As Byte)
    Dim Value As Long = Data(0)
End Sub

' Reads an independently copied array while keeping the original bytes intact.
Function CopyOwnerBytes(ByVal Owner As ByteOwner) As Long
    Call ReadOwnerBytes(Owner.Data)
    CopyOwnerBytes = Owner.Data(0)
End Function

' Records argument evaluation order before any worker can begin.
Function MarkOwner(ByVal Owner As ByteOwner, ByVal Value As Long) As Long
    Owner.Trace = Owner.Trace * 10 + Value
    MarkOwner = Value
End Function

' Native capture layout must preserve scalar widths and ordinary-call ABI.
Sub CaptureArguments(ByVal Owner As ByteOwner, ByVal Left As Long, ByVal Right As Long, ByVal Small As Integer, ByVal Value As Byte, ByVal Flag As Boolean, ByVal Wide As LongLong, ByVal Fraction As Double)
    Owner.Count = Left * 10 + Right
    If Small = 3 And Value = 4 And Flag = True And Wide = 81 Then
        Owner.Trace = Owner.Trace + 1000
    Else
        Owner.Trace = -1
    End If
    Owner.WorkerId = Wide
    Owner.Fraction = Fraction
End Sub

' Captures each expression once, in source order, before dispatch.
Function StartArgumentWork(ByVal Owner As ByteOwner) As LongLong
    Dim Fraction As Double
    StartArgumentWork = CallNew CaptureArguments(Owner, MarkOwner(Owner, 1), MarkOwner(Owner, 2), 3, 4, True, 81, Fraction)
End Function

' Statement-form starts with no arguments still run before program exit.
Sub SignalNoArguments()
    Print 5
End Sub

' Carries a nonzero Double supplied by the independent native observer.
Function StartFractionWork(ByVal Owner As ByteOwner, ByVal Fraction As Double) As LongLong
    StartFractionWork = CallNew CaptureArguments(Owner, 4, 5, 3, 4, True, Owner.WorkerId, Fraction)
End Function
