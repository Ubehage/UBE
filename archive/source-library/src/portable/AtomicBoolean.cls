UBE SOURCE 1 CLASS
Attribute UBE_Name = "AtomicBoolean"

Private Handle As LongLong

' Creates a sequentially consistent Boolean cell initialized to False.
Private Sub Class_Initialize()
    Handle = RuntimeAtomicLongCreate(0)
End Sub

' Releases the private native cell. No user-owned resource is affected.
Private Sub Class_Terminate()
    Call RuntimeAtomicLongDestroy(Handle)
    Handle = 0
End Sub

' Returns the cell's current Boolean value.
Public Function [Load]() As Boolean
    [Load] = RuntimeAtomicLongLoad(Handle) <> 0
End Function

' Replaces the value and returns 1 on success, or 0 with Err on failure.
Public Function Store(ByVal Value As Boolean) As Long
    Dim NumericValue As Long
    If Value Then
        NumericValue = 1
    Else
        NumericValue = 0
    End If
    Store = RuntimeAtomicLongStore(Handle, NumericValue)
End Function

' Replaces the value and returns the Boolean value observed beforehand.
Public Function Exchange(ByVal Value As Boolean) As Boolean
    Dim NumericValue As Long
    If Value Then
        NumericValue = 1
    Else
        NumericValue = 0
    End If
    Exchange = RuntimeAtomicLongExchange(Handle, NumericValue) <> 0
End Function

' Replaces Expected with Replacement when it still matches, and returns the
' Boolean value that was observed.
Public Function CompareExchange(ByVal Expected As Boolean, ByVal Replacement As Boolean) As Boolean
    Dim ExpectedValue As Long
    Dim ReplacementValue As Long
    If Expected Then
        ExpectedValue = 1
    End If
    If Replacement Then
        ReplacementValue = 1
    End If
    CompareExchange = RuntimeAtomicLongCompareExchange(Handle, ExpectedValue, ReplacementValue) <> 0
End Function
