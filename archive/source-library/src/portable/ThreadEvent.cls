UBE SOURCE 1 CLASS
Attribute UBE_Name = "ThreadEvent"

Private Handle As LongLong

' Creates the default auto-reset, nonsignaled event used by New ThreadEvent.
Private Sub Class_Initialize()
    Handle = RuntimeThreadEventCreate(0, 0)
End Sub

' Wakes current waiters and releases the event's internal target resources.
Private Sub Class_Terminate()
    Call RuntimeThreadEventDestroy(Handle)
    Handle = 0
End Sub

' Replaces the default state with the factory-requested reset and signal mode.
' This setup method is intended for CreateThreadEvent.
Public Function Configure(ByVal ManualReset As Boolean, ByVal InitiallySignaled As Boolean) As Long
    Dim ManualValue As Long
    Dim SignalValue As Long
    If ManualReset Then
        ManualValue = 1
    End If
    If InitiallySignaled Then
        SignalValue = 1
    End If
    Call RuntimeThreadEventDestroy(Handle)
    Handle = RuntimeThreadEventCreate(ManualValue, SignalValue)
    If Handle <> 0 Then
        Configure = 1
    Else
        Configure = 0
    End If
End Function

' Signals the event. Auto-reset events release at most one waiter; manual-reset
' events remain signaled until Reset. Returns 0 with Err on failure.
Public Function [Set]() As Long
    [Set] = RuntimeThreadEventSet(Handle)
End Function

' Clears the signaled state and returns 1, or 0 with Err on failure.
Public Function Reset() As Long
    Reset = RuntimeThreadEventReset(Handle)
End Function

' Waits for a signal. -1 waits indefinitely and 0 only checks current state.
' Timeout or cooperative cancellation returns 0 without adding an error.
Public Function Wait(ByVal TimeoutMilliseconds As LongLong) As Long
    Wait = RuntimeThreadEventWait(Handle, TimeoutMilliseconds)
End Function
